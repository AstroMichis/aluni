# frozen_string_literal: true

require "json"
require "yaml"

module Fields
  # A farm and its fields, read through Fields::Profile. Built from one data
  # shape wherever it is kept (the sample file, the preview draft in the
  # session, later the farm and field tables):
  #
  #   { "sample" => bool, "answers" => {}, "confirmed" => [],
  #     "fields" => { key => { "answers" => {}, "confirmed" => [], "snapshot" => bool } },
  #     "plans" => { field_key => crop }, "alerts" => [kind],
  #     "team" => [{ "id", "name", "role", "fields" => [] }],
  #     "tasks" => [{ "id", "title" | "title_key", "field", "member", "due", "done" }] }
  #
  # Answers are what the person said (or corrected); confirmed lists the
  # inferred data they agreed with; snapshot marks the field at the
  # snapshot's point. Measured values come only from the snapshot.
  class Farm
    SAMPLE_PATH = Rails.root.join("config/samples/farm.yml")
    # Hectares; the upper bound of each size class (an open question per country).
    SIZE_LIMITS = { "small" => 2, "medium" => 50 }.freeze
    # States that need the person: what they still have to confirm or tell us.
    TODO_STATES = %i[to_confirm unanswered gap].freeze
    DONE_STATES = %i[answered confirmed corrected].freeze

    # state: answered | unanswered (asked data); auto | to_confirm | confirmed
    # | corrected (inferred data); pending (a documented source, not connected
    # yet); gap (no documented source: the person tells us).
    # source: the source that produced the value (nil for what the person said).
    Reading = Struct.new(:subject, :datum, :state, :values, :source, keyword_init: true) do
      def known? = %i[answered auto to_confirm confirmed corrected].include?(state)
      def todo? = TODO_STATES.include?(state) && !datum.optional
      def value = values["value"]
      def layer = subject.layer
      def scale = source ? source.scale : datum.scale(layer)
      def confidence = Profile::CONFIDENCE[scale]
      def dom_id = "reading-#{subject.key}-#{datum.key}"
    end

    # A farm or one of its fields.
    class Subject
      attr_reader :key, :layer, :answers, :confirmed

      def initialize(key:, layer:, data:, snapshot:, profile:, level:)
        @key = key
        @layer = layer
        @answers = data["answers"].to_h
        @confirmed = Array(data["confirmed"])
        @snapshot = snapshot
        @profile = profile
        @level = level
      end

      def reading(datum)
        datum = @profile.fetch(datum) unless datum.is_a?(Profile::Datum)
        Reading.new(subject: self, datum: datum, **read(datum))
      end

      def snapshot? = !@snapshot.nil?
      def readings(data = @profile.data(@level)) = data.map { |datum| reading(datum) }
      def todo = readings.select(&:todo?)

      # [done, total] over what the person can settle (asked or confirmed data).
      def progress
        settle = readings.select { |r| !r.datum.optional && (r.datum.asked?(layer) || r.datum.origin(layer) == "confirm" || r.state == :gap) }
        [ settle.count { |r| DONE_STATES.include?(r.state) }, settle.size ]
      end

      private

      def read(datum)
        answer = @answers[datum.key]
        unless answer.nil?
          # What the person told us where no source exists is an answer, not a correction.
          return { state: :answered, values: { "value" => answer } } if datum.asked?(layer) || datum.gap?(layer)
          return { state: :corrected, values: { "value" => answer } }
        end
        return { state: :unanswered, values: {} } if datum.asked?(layer)

        values = datum.snapshot.transform_values { |path| dig(path) }
        if values.any? && values.values.none?(&:blank?)
          state = if @confirmed.include?(datum.key) then :confirmed
          elsif datum.origin(layer) == "confirm" then :to_confirm
          else :auto
          end
          return { state: state, values: values, source: datum.snapshot_source }
        end

        { state: datum.gap?(layer) ? :gap : :pending, values: {} }
      end

      # "site_attributes.slope", or "site_attributes.crop_*" for every key
      # with that prefix (suffix => value).
      def dig(path)
        return if @snapshot.nil?

        *parents, last = path.split(".")
        node = parents.empty? ? @snapshot : @snapshot.dig(*parents)
        return node&.dig(last) unless last.end_with?("*")

        prefix = last.delete_suffix("*")
        node.to_h.filter_map { |k, v| [ k.delete_prefix(prefix), v ] if k.start_with?(prefix) }.to_h.presence
      end
    end

    class Field < Subject
      def area = answers["area"].to_f
      def crop = answers["current_crop"]
      def name = answers["name"]
      def empty? = crop.blank?

      # [[label, crop], ...] oldest first: the history, this season when it is
      # not already the last year of the history, and the plan if given.
      def seasons(plan = nil)
        list = history.to_a
        list << [ "now", crop ] if crop.present? && list.last&.last != crop
        list << [ "plan", plan ] if plan.present?
        list
      end

      # Year => crop key, from the person or the crop map, oldest first.
      def history
        values = reading("crop_history").values
        (values["value"] || values["years"]).to_h.to_h { |year, crop| [ year.to_s, crop.to_s.parameterize(separator: "_") ] }.sort.to_h
      end
    end

    class Root < Subject
      attr_reader :fields, :location

      def initialize(fields:, location:, period:, sample:, data:, **)
        super(data: data, **)
        @fields = fields
        @location = location
        @period = period
        @sample = sample
        @extras = data
      end

      def plans = @extras["plans"].to_h
      def team = Array(@extras["team"])
      def tasks = Array(@extras["tasks"])
      def alerts = Array(@extras["alerts"])
      def member(id) = team.find { |m| m["id"] == id }

      def sample? = @sample
      def total_area = fields.sum(&:area)
      def field(key) = fields.find { |f| f.key == key.to_s }
      def answered?(datum_key) = !answers[datum_key.to_s].nil?

      # Farm-level onboarding steps run once: later fields skip what is answered.
      def needs?(step)
        sample? || !step.farm || step.data.any? { |d| d.level == "farm" && d.asked?(layer) && !answered?(d.key) }
      end

      # The dates the snapshot's season values cover.
      def period = Array(@period).map { |day| Date.strptime(day, "%Y%m%d") }

      # The five axes of the user classification (docs/FIELDS.md).
      def classification
        size = SIZE_LIMITS.find { |_, limit| total_area < limit }&.first || "large"
        { "size" => (size if fields.any?), "water" => answers["water_access"], "inputs" => answers["fertilizer_level"],
          "goal" => Array(answers["goals"]).first, "tech" => answers["tech_level"] }.compact
      end
    end

    class << self
      def sample_data = YAML.safe_load(File.read(SAMPLE_PATH)).merge("sample" => true)

      def snapshot
        return load_snapshot if Rails.env.test?

        @snapshot ||= load_snapshot
      end

      def build(data, profile: Profile.current)
        layer = sample_data.fetch("layer")
        fields = data["fields"].to_h.map do |key, body|
          Field.new(key: key, layer: layer, data: body, snapshot: (snapshot if body["snapshot"]), profile: profile, level: "field")
        end
        Root.new(key: "farm", layer: layer, data: data, snapshot: snapshot, profile: profile, level: "farm",
                 fields: fields, location: snapshot.fetch("location"), period: snapshot["period"], sample: data["sample"] == true)
      end

      private

      def load_snapshot = JSON.parse(File.read(Rails.root.join(YAML.safe_load(File.read(SAMPLE_PATH)).fetch("snapshot"))))
    end
  end
end
