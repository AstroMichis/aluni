# frozen_string_literal: true

module Fields
  # The menu sections' view of one user's farm: the onboarding models
  # (FarmerProfile, Farm, Field, FieldCrop) and what the public data sources
  # returned for each field's pin (FieldObservation), read through
  # Fields::Profile. Screens only ask for `reading(datum)`, `todo` and
  # `progress`; writes go through Fields::AnswerService.
  class Farm
    ACRES_PER_HECTARE = 2.47105
    UNKNOWN = "unknown"
    TODO_STATES = %i[to_confirm unanswered].freeze
    DONE_STATES = %i[answered confirmed].freeze

    # state: answered | unanswered (asked data); auto | to_confirm | confirmed
    # (from a source); pending (the source has not answered yet); failed (it
    # answered with an error); needs_pin (no pin to ask with); gap (no source
    # covers it here). source: the registry source behind the value (nil for
    # the person's own answer); proposal: what "Looks right" would save.
    Reading = Struct.new(:subject, :datum, :state, :values, :source, :proposal, keyword_init: true) do
      def known? = %i[answered auto to_confirm confirmed].include?(state)
      def todo? = TODO_STATES.include?(state) && datum.essential
      def value = values["value"]
      def layer = subject.layer
      def scale = source ? source.scale : datum.scale_for(layer)
      def confidence = Profile::CONFIDENCE[scale]
      def dom_id = "reading-#{subject.key}-#{datum.key}"
    end

    class Subject
      attr_reader :profile

      def reading(datum)
        datum = profile.fetch(datum) unless datum.is_a?(Profile::Datum)
        Reading.new(subject: self, datum: datum, **read(datum))
      end

      # Every datum of this level is read once; a group gets its share of them.
      def readings(data = nil)
        @readings ||= profile.data(level).map { |datum| reading(datum) }
        return @readings unless data

        keys = data.map(&:key)
        @readings.select { |r| keys.include?(r.datum.key) }
      end

      def todo = (@todo ||= readings.select(&:todo?))

      # [done, total] over the essential answers (what the comparison needs).
      def progress
        @progress ||= begin
          settle = readings.select { |r| r.datum.essential && r.state != :gap }
          [ settle.count { |r| DONE_STATES.include?(r.state) }, settle.size ]
        end
      end

      private

      def read(datum)
        value = datum.column && column_value(datum.column)
        return answered(datum, value) if present?(value)

        observed = observed(datum)
        return observed if observed

        # Anything with an answer column the person can fill is theirs to answer.
        { state: datum.column && datum.origin(layer) != "auto" ? :unanswered : missing_state(datum), values: {} }
      end

      def answered(datum, value)
        state = if datum.asked?(layer) then :answered
        elsif datum.confirm?(layer) then :confirmed
        else :auto
        end
        source = state == :auto ? datum.sources_for(layer).find(&:connected?) : nil
        { state: state, values: { "value" => value }, source: source }
      end

      # What a source says, when it has said it.
      def observed(datum)
        return if datum.observation.empty?

        # Per value, the first alternative that has it (3DEP before NASADEM).
        found = datum.observation.transform_values do |alternatives|
          alternatives.lazy.map { |(obs, path)| [ obs, observation_payload(obs)&.dig(*path) ] }.find { |(_, v)| !v.nil? }
        end
        return if found.values.any?(&:nil?)

        values = found.transform_values(&:last)

        values = values.transform_values { |v| v.is_a?(Numeric) && datum.scale ? v * datum.scale : v }
        source = profile.observation_sources[found.values.first.first]
        if datum.confirm?(layer)
          proposal = Proposals.call(datum.propose, values)
          return proposal.nil? ? nil : { state: :to_confirm, values: values, source: source, proposal: proposal }
        end
        { state: :auto, values: values, source: source }
      end

      def missing_state(datum)
        return :needs_pin if !located? && datum.observation.any?
        return :gap if datum.gap?(layer)

        statuses = datum.observed_sources.map { |obs| observation_status(obs) }
        return :failed if statuses.include?("failed")

        statuses.include?(nil) || statuses.include?("pending") ? :pending : :gap
      end

      def present?(value) = !(value.nil? || value == "" || value == [] || value == {} || value == UNKNOWN)
      def located? = false
      def observation_payload(_source) = nil
      def observation_status(_source) = nil
    end

    class Field < Subject
      attr_reader :record

      def initialize(record, profile:)
        @record = record
        @profile = profile
      end

      def level = "field"
      def key = record.id.to_s
      def located? = record.located?
      def layer = observation_payload("fcc").present? ? "us" : "global"
      def name = record.name.presence
      def area_hectares = record.area.to_f / (record.area_unit_acres? ? ACRES_PER_HECTARE : 1)
      def observation(source) = record.observation(source)
      def observations = record.observations

      def main_crops = @main_crops ||= record.field_crops.select(&:role_main?).sort_by { |c| [ c.season_year, -c.portion, c.id.to_i ] }
      # The second crop that has followed each main crop in the same season, from the
      # history (latest first wins): { "triticum-aestivum" => <FieldCrop soybeans> }.
      def double_crops
        @double_crops ||= begin
          mains = main_crops.group_by(&:season_year).transform_values(&:first) # a split season: its largest crop
          record.field_crops.select { |c| c.role_second? && c.season_year <= Date.current.year }.sort_by(&:season_year)
                .each_with_object({}) do |second, map|
                  main = mains[second.season_year]
                  key = main && (Crops::Agronomy.find(main)&.key || main.crop_key)
                  map[key] = second if key
                end
        end
      end

      # Cover crops sown between main seasons, up to this season, oldest first.
      def cover_crops = record.field_crops.select { |c| c.role_cover? && c.season_year <= Date.current.year }.sort_by(&:season_year)

      # A season may split the field between crops (FieldCrop#share, #cells):
      # its crops, the largest first.
      def season_crops(year) = main_crops.select { |c| c.season_year == year.to_i }
      def current_season = main_crops.map(&:season_year).select { |y| y <= Date.current.year }.max
      def current_crops = current_season ? season_crops(current_season) : []
      def plan_crops = season_crops(Date.current.year + 1)
      def split?(year = current_season) = season_crops(year).any? { |c| !c.whole_field? }
      def unassigned_share(year = current_season) = year ? [ 1 - season_crops(year).sum(&:portion), 0 ].max.round(4) : 1.0

      # The largest crop of this season and of the plan, for what reads one crop.
      def current_crop = current_crops.first
      def plan = plan_crops.first
      def crop = current_crop&.crop_name
      def empty? = current_crop.nil?

      # The pieces of ground with the same crops (Fields::Zone), largest first.
      def zones = @zones ||= Zone.for(self)
      def zone(index) = zones[index.to_i] || zones.first

      # Season year => the season's largest crop, oldest first, up to this season.
      def history = main_crops.select { |c| c.season_year <= Date.current.year }.reverse.to_h { |c| [ c.season_year.to_s, c ] }.sort.to_h

      # [[label, crop], ...] for Crops::RotationCheck: the seasons, then the plan.
      def seasons
        list = history.map { |year, c| [ year, c ] }
        list << [ "plan", plan ] if plan
        list
      end

      # What the sources propose for the farmer to take: each datum to confirm,
      # and the CDL years as one.
      def suggestions_count = readings.count { |r| r.state == :to_confirm } + (cdl_proposal.any? ? 1 : 0)

      # CDL years the person has not recorded yet (US pins).
      def cdl_proposal
        years = observation_payload("cdl")&.dig("years").to_h
        years.reject { |year, _| history.key?(year) }
      end

      def image_url
        return unless located?

        Onboarding::AreaImage.url(latitude: record.latitude, longitude: record.longitude, span: 0.4, size: 480)
      end

      private

      def column_value(path)
        section, attr, sub = path.split(".")
        case section
        when "field"
          return [ record.latitude.to_f, record.longitude.to_f ] if attr == "location" && located?
          return record.soil[sub] if attr == "soil"

          record.respond_to?(attr) ? record.public_send(attr) : nil
        when "crops"
          return history.to_h { |year, _| [ year, season_names(year) ] }.presence if attr == "history"
          return current_crop&.public_send(sub) if sub

          current_season && season_names(current_season)
        end
      end

      # "Corn" or, on a split season, "Corn + Beans".
      def season_names(year) = season_crops(year).map(&:crop_name).join(" + ")

      def observation_payload(source)
        obs = observation(source)
        obs&.ok? ? obs.payload : nil
      end

      def observation_status(source) = observation(source)&.status
    end

    class Root < Subject
      attr_reader :user, :farm, :fields

      def self.for(user, profile: Profile.current)
        farm = user.farms.includes(fields: %i[field_crops observations]).first
        new(user: user, farm: farm, profile: profile)
      end

      def initialize(user:, farm:, profile:)
        @user = user
        @farm = farm
        @profile = profile
        @fields = farm ? farm.fields.map { |record| Field.new(record, profile: profile) } : []
      end

      def level = "farm"
      def key = "farm"
      def record_profile = user.farmer_profile
      def main_field = fields.first
      def layer = main_field&.layer || "global"
      def located? = main_field&.located? || false
      def field(key) = fields.find { |f| f.key == key.to_s }
      def total_area = fields.sum(&:area_hectares)
      def alerts = Array(record_profile&.notification_preferences.to_h["weather"])

      # The farmer's profile in a few words: segment, team, budget, first goal.
      def classification
        p = record_profile
        return {} unless p

        { "segment" => p.segment, "team" => p.team, "budget_level" => p.budget_level, "goals" => p.goals.first }
          .reject { |_, v| v.blank? || v == UNKNOWN }
      end

      private

      def column_value(path)
        section, attr = path.split(".")
        target = section == "profile" ? record_profile : farm
        target&.public_send(attr)
      end

      def observation_payload(source)
        obs = main_field&.observation(source)
        obs&.ok? ? obs.payload : nil
      end

      def observation_status(source) = main_field&.observation(source)&.status
    end

    def self.for(user) = Root.for(user)
  end
end
