# frozen_string_literal: true

module Weather
  # The season so far at the farm's point: the daily NASA POWER rows that
  # farm_data.py writes (long format: source,variable,value,unit,date,lat,lon),
  # summed up for the weather screens. Regional context (about 50 km), never
  # the field's own values. Thresholds match farm_data.py's summary.
  class Season
    FROST_C = 0.0
    HEAT_C = 32.0          # farm_data.py heat_stress_days_gt32c
    HEAVY_RAIN_MM = 25.0
    DRY_DAY_MM = 1.0
    DRY_SPELL_DAYS = 10    # shorter runs are not worth an alert
    GROWING = (4..10)      # months when frost and dry spells matter to a crop
    VARIABLES = %w[air_temp_min air_temp_mean air_temp_max precipitation root_zone_soil_wetness].freeze

    Day = Struct.new(:date, :tmin, :tmean, :tmax, :rain, :wetness, keyword_init: true)
    Event = Struct.new(:kind, :from, :to, :value, keyword_init: true) do
      def days = ((to || from) - from).to_i + 1
    end

    def self.load(path = default_path)
      return new(read(path)) if Rails.env.test?

      @cache ||= {}
      @cache[path.to_s] ||= new(read(path))
    end

    def self.default_path = Rails.root.join(YAML.safe_load(File.read(Fields::Farm::SAMPLE_PATH)).fetch("series"))

    def self.read(path)
      # NASA POWER rows carry no quoted fields, so a plain split reads them
      # (other sources' rows, e.g. soil map unit names, may hold commas).
      rows = Hash.new { |h, date| h[date] = {} }
      File.foreach(path) do |line|
        next unless line.start_with?("NASA POWER,")

        _source, variable, value, _unit, date = line.chomp.split(",", 6)
        rows[Date.iso8601(date)][variable] = Float(value) if VARIABLES.include?(variable)
      end
      rows.sort.map do |date, v|
        Day.new(date: date, tmin: v["air_temp_min"], tmean: v["air_temp_mean"], tmax: v["air_temp_max"],
                rain: v["precipitation"], wetness: v["root_zone_soil_wetness"])
      end
    end

    attr_reader :days

    def initialize(days)
      @days = days.freeze
    end

    def any? = days.any?
    def from = days.first&.date
    def to = days.last&.date

    def totals
      {
        rain: days.sum(&:rain).round(1),
        temp: mean(days.map(&:tmean)),
        frost_days: days.count { |d| d.tmin <= FROST_C },
        heat_days: days.count { |d| d.tmax > HEAT_C },
        wetness: mean(days.map(&:wetness), 2)
      }
    end

    # Rain summed per 7-day block from the first day: [first date, mm].
    def weekly_rain
      days.each_slice(7).map { |week| [ week.first.date, week.sum(&:rain).round(1) ] }
    end

    # One row per month: rain, mean low and high, mean root-zone wetness.
    def monthly
      days.group_by { |d| d.date.beginning_of_month }.map do |month, list|
        { month: month, rain: list.sum(&:rain).round(1), tmin: mean(list.map(&:tmin)),
          tmax: mean(list.map(&:tmax)), wetness: mean(list.map(&:wetness), 2) }
      end
    end

    # The last frost before midyear and the first after it (nil when none).
    def frost_free
      spring = days.select { |d| d.date.month < 7 && d.tmin <= FROST_C }.last&.date
      fall = days.find { |d| d.date.month >= 7 && d.tmin <= FROST_C }&.date
      { last_spring: spring, first_fall: fall }
    end

    # What would have raised an alert this season, oldest first.
    def events
      list = days.select { |d| d.tmin <= FROST_C && GROWING.cover?(d.date.month) }.map { |d| Event.new(kind: "frost", from: d.date, value: d.tmin) }
      list += days.select { |d| d.tmax > HEAT_C }.map { |d| Event.new(kind: "heat", from: d.date, value: d.tmax) }
      list += days.select { |d| d.rain >= HEAVY_RAIN_MM }.map { |d| Event.new(kind: "heavy_rain", from: d.date, value: d.rain) }
      list += dry_spells
      list.sort_by(&:from)
    end

    private

    def dry_spells
      days.chunk_while { |a, b| a.rain < DRY_DAY_MM && b.rain < DRY_DAY_MM }
          .select { |run| run.size >= DRY_SPELL_DAYS && run.first.rain < DRY_DAY_MM && GROWING.cover?(run.first.date.month) }
          .map { |run| Event.new(kind: "dry_spell", from: run.first.date, to: run.last.date, value: run.size) }
    end

    def mean(values, precision = 1) = values.empty? ? nil : (values.sum / values.size).round(precision)
  end
end
