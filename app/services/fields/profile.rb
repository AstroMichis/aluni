# frozen_string_literal: true

require "yaml"

module Fields
  # config/field_profile.yml, parsed and validated: every datum of a farm and
  # its fields, the sources that cover it per layer, and the onboarding steps.
  # Cached outside test, like Notifications::Purposes.
  class Profile
    class Invalid < StandardError; end

    PATH = Rails.root.join("config/field_profile.yml")
    LAYERS = %w[global us].freeze
    LEVELS = %w[farm field].freeze
    ORIGINS = %w[ask auto confirm].freeze
    SCALES = %w[parcel zone region species].freeze
    CONFIDENCE = { "parcel" => "high", "zone" => "medium", "region" => "low" }.freeze
    INPUTS = %w[pin found boundary choice history rank review].freeze

    Source = Struct.new(:id, :name, :layer, :scale, :resolution, :doc, keyword_init: true) do
      def documented? = doc.present?
      def confidence = CONFIDENCE[scale]
    end

    Datum = Struct.new(:key, :level, :group, :origins, :sources, :snapshot, :snapshot_source, :precision, :options,
                       :multiple, :optional, :feeds, :months, :number, keyword_init: true) do
      def origin(layer) = origins.fetch(layer)
      def asked?(layer) = origin(layer) == "ask"

      # The us layer adds its own sources in front of the global ones.
      def sources_for(layer) = layer == "us" ? (sources["us"] + sources["global"]).uniq : sources["global"]

      # The finest scale among the sources: what the value can claim to describe.
      def scale(layer)
        sources_for(layer).map(&:scale).min_by { |s| SCALES.index(s) }
      end

      def confidence(layer) = CONFIDENCE[scale(layer)]
      def layered? = origins.values.uniq.size > 1

      # No source at all, or none documented yet: the person has to tell us.
      def gap?(layer) = !asked?(layer) && sources_for(layer).none?(&:documented?)
    end

    Step = Struct.new(:key, :input, :data, :farm, keyword_init: true)

    class << self
      def current
        return load_file(PATH) if Rails.env.test?

        @current ||= load_file(PATH)
      end

      def load_file(path) = new(YAML.safe_load(File.read(path)), source: path.to_s)
    end

    attr_reader :sources, :steps

    def initialize(data, source:)
      @source = source
      @sources = data.fetch("sources").to_h { |id, body| [ id, build_source(id, body) ] }.freeze
      @data = LEVELS.to_h { |level| [ level, data.dig("data", level).to_h { |key, body| [ key, build_datum(key, level, body) ] } ] }.freeze
      @index = @data.values.reduce(:merge).freeze
      @steps = data.fetch("onboarding").map { |body| build_step(body) }.freeze
    rescue KeyError, NoMethodError => e
      raise Invalid, "#{source}: #{e.message}"
    end

    def data(level) = @data.fetch(level.to_s).values
    def fetch(key) = @index.fetch(key.to_s)
    def groups(level) = data(level).group_by(&:group)

    # Data that no documented source covers on this layer: the person has to tell us.
    def gaps(layer) = @index.values.select { |datum| datum.gap?(layer) }

    private

    def build_source(id, body)
      fail!("source #{id}", "layer must be one of #{LAYERS.join(', ')}") unless LAYERS.include?(body["layer"])
      fail!("source #{id}", "scale must be one of #{SCALES.join(', ')}") unless SCALES.include?(body["scale"])
      Source.new(id: id, **body.slice("name", "layer", "scale", "resolution", "doc").symbolize_keys).freeze
    end

    def build_datum(key, level, body)
      fail!(key, "options: months is only for asked or confirmed data") if body["options"] == "months" && body["origin"] == "auto"
      origins = body["origin"].is_a?(Hash) ? body["origin"] : LAYERS.index_with(body["origin"])
      fail!(key, "origin must be one of #{ORIGINS.join(', ')} per layer") unless LAYERS.all? { |l| ORIGINS.include?(origins[l]) }

      sources = LAYERS.index_with do |layer|
        Array(body.dig("sources", layer)).map { |id| @sources.fetch(id) { fail!(key, "unknown source #{id}") } }
      end
      fail!(key, "sources: us ids must be us-layer sources") if sources["us"].any? { |s| s.layer != "us" }
      fail!(key, "snapshot needs snapshot_source") if body["snapshot"].present? && body["snapshot_source"].blank?
      snapshot_source = body["snapshot_source"] && @sources.fetch(body["snapshot_source"]) { fail!(key, "unknown snapshot_source") }

      Datum.new(key: key, level: level, group: body.fetch("group"), origins: origins.freeze, sources: sources.freeze,
                snapshot: body["snapshot"].to_h.freeze, snapshot_source: snapshot_source, precision: body.fetch("precision", 1),
                options: (body["options"] == "months" ? ("1".."12").to_a : Array(body["options"])).freeze,
                months: body["options"] == "months", number: body["number"] == true,
                multiple: body["multiple"] == true, optional: body["optional"] == true,
                feeds: Array(body["feeds"]).freeze).freeze
    end

    def build_step(body)
      fail!("step #{body['step']}", "input must be one of #{INPUTS.join(', ')}") unless INPUTS.include?(body["input"])
      data = Array(body["data"]).map { |key| fetch(key) }
      Step.new(key: body.fetch("step"), input: body["input"], data: data.freeze, farm: body["farm"] == true).freeze
    rescue KeyError => e
      fail!("step #{body['step']}", e.message)
    end

    def fail!(where, message) = raise(Invalid, "#{@source}: #{where}: #{message}")
  end
end
