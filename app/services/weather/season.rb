# frozen_string_literal: true

module Weather
  # The season so far at a field's pin: the daily NASA POWER values that
  # Fields::FetchObservationsJob stored (FieldObservation "nasa_power"),
  # summed up for the weather screens, plus the long-term monthly normals.
  # Regional context (about 50 km), never the field's own values.
  class Season
    FROST_C = 0.0
    HEAT_C = 32.0          # as farm_data.py's heat_stress_days_gt32c
    HEAVY_RAIN_MM = 25.0
    DRY_DAY_MM = 1.0
    DRY_SPELL_DAYS = 10    # shorter runs are not worth an alert
    GROWING = (4..10)      # months when frost and dry spells matter to a crop
    MONTHS = %w[JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC].freeze

    Day = Struct.new(:date, :tmin, :tmean, :tmax, :rain, :wetness, keyword_init: true)
    Event = Struct.new(:kind, :from, :to, :value, keyword_init: true) do
      def days = ((to || from) - from).to_i + 1
    end

    # From a field's "nasa_power" observation; an empty season when there is none.
    def self.for(observation)
      payload = observation&.ok? ? observation.payload.to_h : {}
      daily = payload["daily"].to_h
      days = daily["T2M"].to_h.keys.sort.filter_map do |key|
        values = %w[T2M_MIN T2M T2M_MAX PRECTOTCORR GWETROOT].map { |name| daily.dig(name, key) }
        next if values.any?(&:nil?)

        tmin, tmean, tmax, rain, wetness = values
        Day.new(date: Date.strptime(key, "%Y%m%d"), tmin: tmin, tmean: tmean, tmax: tmax, rain: rain, wetness: wetness)
      end
      new(days, payload["climatology"].to_h)
    end

    attr_reader :days, :climatology

    def initialize(days, climatology = {})
      @days = days.freeze
      @climatology = climatology
    end

    # Month => long-term mean temperature, low, high (°C) and rain (mm/day).
    def normals
      MONTHS.each_with_index.to_h do |name, i|
        [ i + 1, %w[T2M T2M_MIN T2M_MAX PRECTOTCORR].to_h { |p| [ p, climatology.dig(p, name) ] } ]
      end
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
