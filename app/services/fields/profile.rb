# frozen_string_literal: true

require "yaml"

module Fields
  # config/field_profile.yml, parsed and validated: every datum of a farm and
  # its fields, where the answer lives in the onboarding models, which source
  # fills or proposes it, and the add-a-field steps. Answer options come from
  # Onboarding::Allowlist (itself read from the models), so the menu and the
  # chat share one vocabulary. Cached outside test.
  class Profile
    class Invalid < StandardError; end

    PATH = Rails.root.join("config/field_profile.yml")
    LAYERS = %w[global us].freeze
    LEVELS = %w[farm field].freeze
    ORIGINS = %w[ask auto confirm].freeze
    SCALES = %w[parcel zone region species].freeze
    STATUSES = %w[connected reference planned gap].freeze
    CONFIDENCE = { "parcel" => "high", "zone" => "medium", "region" => "low" }.freeze
    INPUTS = %w[pin details crop history review].freeze
    PROPOSERS = %w[texture_class drainage_class number cdl_history].freeze
    COLUMN = /\A(profile|farm|field|crops)\.[a-z_.]+\z/

    Source = Struct.new(:id, :name, :layer, :scale, :resolution, :doc, :status, keyword_init: true) do
      def documented? = doc.present?
      def connected? = status == "connected"
      def confidence = CONFIDENCE[scale]
    end

    Datum = Struct.new(:key, :level, :group, :origins, :column, :values_attr, :options, :months, :multiple, :number,
                       :essential, :observation, :propose, :scale, :sources, :precision, :feeds, keyword_init: true) do
      def origin(layer) = origins.fetch(layer)
      def asked?(layer) = origin(layer) == "ask"
      def confirm?(layer) = origin(layer) == "confirm"

      # The us layer adds its own sources in front of the global ones.
      def sources_for(layer) = layer == "us" ? (sources["us"] + sources["global"]).uniq : sources["global"]

      def scale_for(layer) = sources_for(layer).map(&:scale).min_by { |s| SCALES.index(s) }
      def confidence(layer) = CONFIDENCE[scale_for(layer)]
      def layered? = origins.values.uniq.size > 1
      def optional = !essential

      # Nothing connected can fill it on this layer and nobody is asked: a gap.
      def gap?(layer) = !asked?(layer) && sources_for(layer).none?(&:connected?)

      # The observation sources it reads ("ssurgo", "nasa_power", ...), fallbacks included.
      def observed_sources = observation.values.flatten(1).map(&:first).uniq
    end

    Step = Struct.new(:key, :input, :data, keyword_init: true)

    HISTORY_YEARS = 3

    class << self
      # The past seasons the history inputs ask about, latest first ("2025", "2024", "2023").
      def history_years = (1..HISTORY_YEARS).map { |n| (Date.current.year - n).to_s }

      def current
        return load_file(PATH) if Rails.env.test?

        @current ||= load_file(PATH)
      end

      def load_file(path) = new(YAML.safe_load(File.read(path)), source: path.to_s)
    end

    attr_reader :sources, :steps, :observation_sources

    def initialize(data, source:)
      @source = source
      @sources = data.fetch("sources").to_h { |id, body| [ id, build_source(id, body) ] }.freeze
      @observation_sources = data.fetch("observations").to_h { |obs, id| [ obs, @sources.fetch(id) { fail!("observations", "unknown source #{id}") } ] }.freeze
      @data = LEVELS.to_h { |level| [ level, data.dig("data", level).to_h { |key, body| [ key, build_datum(key, level, body) ] } ] }.freeze
      @index = @data.values.reduce(:merge).freeze
      @steps = data.fetch("onboarding").map { |body| build_step(body) }.freeze
    rescue KeyError, NoMethodError => e
      raise Invalid, "#{source}: #{e.message}"
    end

    def data(level) = @data.fetch(level.to_s).values
    def fetch(key) = @index.fetch(key.to_s)
    def groups(level) = data(level).group_by(&:group)

    # Data that no connected source covers on this layer: the person tells us.
    def gaps(layer) = @index.values.select { |datum| datum.gap?(layer) }

    private

    def build_source(id, body)
      fail!("source #{id}", "layer must be one of #{LAYERS.join(', ')}") unless LAYERS.include?(body["layer"])
      fail!("source #{id}", "scale must be one of #{SCALES.join(', ')}") unless SCALES.include?(body["scale"])
      fail!("source #{id}", "status must be one of #{STATUSES.join(', ')}") unless STATUSES.include?(body["status"])
      Source.new(id: id, **body.slice("name", "layer", "scale", "resolution", "doc", "status").symbolize_keys).freeze
    end

    def build_datum(key, level, body)
      origins = body["origin"].is_a?(Hash) ? body["origin"] : LAYERS.index_with(body["origin"])
      fail!(key, "origin must be one of #{ORIGINS.join(', ')} per layer") unless LAYERS.all? { |l| ORIGINS.include?(origins[l]) }
      column = body["column"]
      fail!(key, "column #{column.inspect} is not a model path") if column && !column.match?(COLUMN)
      fail!(key, "asked data need a column") if column.nil? && origins.values.include?("ask")
      fail!(key, "propose must be one of #{PROPOSERS.join(', ')}") if body["propose"] && !PROPOSERS.include?(body["propose"])

      sources = LAYERS.index_with do |layer|
        Array(body.dig("sources", layer)).map { |id| @sources.fetch(id) { fail!(key, "unknown source #{id}") } }
      end
      fail!(key, "sources: us ids must be us-layer sources") if sources["us"].any? { |s| s.layer != "us" }
      observation = body["observation"].to_h.transform_values do |paths|
        paths.split("|").map do |path|
          obs, *rest = path.strip.split(".")
          fail!(key, "unknown observation source #{obs}") unless @observation_sources.key?(obs)
          [ obs, rest ].freeze
        end.freeze
      end

      Datum.new(key: key, level: level, group: body.fetch("group"), origins: origins.freeze, column: column,
                values_attr: body["values"] || column.to_s.split(".").last, options: options_for(column, body).freeze,
                months: body["options"] == "months", multiple: body["multiple"] == true, number: body["number"] == true,
                essential: body["essential"] == true, observation: observation.freeze, propose: body["propose"],
                scale: body["scale"], sources: sources.freeze, precision: body.fetch("precision", 1),
                feeds: Array(body["feeds"]).freeze).freeze
    end

    # The allowed answers for a column, from Onboarding::Allowlist.
    def options_for(column, body)
      return ("1".."12").to_a if body["options"] == "months"

      section, attr, sub = column.to_s.split(".")
      allow = Onboarding::Allowlist
      case section
      when "profile" then allow::PROFILE_ENUMS[attr] || allow::PROFILE_LISTS[attr] || []
      when "field"
        if attr == "soil" then sub == "problems" ? allow::SOIL_PROBLEMS : allow::SOIL_ENUMS.fetch(sub, [])
        else allow::FIELD_ENUMS.fetch(attr, [])
        end
      else []
      end
    end

    def build_step(body)
      fail!("step #{body['step']}", "input must be one of #{INPUTS.join(', ')}") unless INPUTS.include?(body["input"])
      Step.new(key: body.fetch("step"), input: body["input"], data: Array(body["data"]).map { |key| fetch(key) }.freeze).freeze
    rescue KeyError => e
      fail!("step #{body['step']}", e.message)
    end

    def fail!(where, message) = raise(Invalid, "#{@source}: #{where}: #{message}")
  end
end
