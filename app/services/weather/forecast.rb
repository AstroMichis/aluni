# frozen_string_literal: true

module Weather
  # The next seven days at a field's pin from Meteomatics (hourly, its own
  # blend of weather models; Meteomatics::Client#forecast), summed up per local
  # day for the weather screen: lows and highs, rain and its chance, gusts,
  # evapotranspiration, the soil at 5 cm and its moisture, and the day's
  # alerts with the same lines as Weather::Season (frost, heat, heavy rain)
  # plus strong wind. Fields carry no time zone, so a day is the local solar
  # day: UTC shifted by the pin's longitude (15° an hour).
  class Forecast
    HOURS = 168
    FROST_C = Season::FROST_C
    HEAT_C = Season::HEAT_C
    HEAVY_RAIN_MM = Season::HEAVY_RAIN_MM
    GUST_MS = 15.0 # about 55 km/h: spraying stops, light covers and young plants suffer
    ALERTS = %w[frost heat heavy_rain wind].freeze

    Day = Struct.new(:date, :tmin, :tmax, :rain, :rain_chance, :gust, :et, :soil_tmin, :soil_moisture, keyword_init: true) do
      def alerts
        list = []
        list << "frost" if (tmin && tmin <= FROST_C) || (soil_tmin && soil_tmin <= FROST_C)
        list << "heat" if tmax && tmax >= HEAT_C
        list << "heavy_rain" if rain && rain >= HEAVY_RAIN_MM
        list << "wind" if gust && gust >= GUST_MS
        list
      end
    end

    attr_reader :error

    # For a Fields::Farm field; an empty forecast without a pin, credentials or an answer.
    def self.for(field, client: Meteomatics::Client.new)
      return new({}, longitude: 0, error: :needs_pin) unless field&.located?
      return new({}, longitude: 0, error: :not_configured) unless Meteomatics::Client.configured?

      series = client.forecast(lat: field.record.latitude, lon: field.record.longitude, hours: HOURS)
      new(series || {}, longitude: field.record.longitude.to_f, error: series ? nil : client.last_error&.dig(:type) || :unavailable)
    rescue Platform::ServicePaused
      new({}, longitude: 0, error: :paused)
    end

    def initialize(series, longitude:, error: nil)
      @series = series.to_h
      @offset = (longitude / 15.0).round.hours
      @error = error
    end

    def any? = days.any?

    # Whole local days only, from today.
    def days
      @days ||= hours.group_by { |h| h[:at].to_date }.filter_map do |date, list|
        next if list.size < 20 && date != hours.first[:at].to_date # the partial last day says too little

        Day.new(date: date, tmin: min(list, "t_2m:C"), tmax: max(list, "t_2m:C"), rain: sum(list, "precip_1h:mm"),
                rain_chance: max(list, "prob_precip_1h:p"), gust: max(list, "wind_gusts_10m_1h:ms"),
                et: sum(list, "evapotranspiration_1h:mm"), soil_tmin: min(list, "t_-5cm:C"),
                soil_moisture: list.filter_map { |h| h["soil_moisture_index_-15cm:idx"] }.last&.round(2))
      end
    end

    def alerts = days.flat_map { |d| d.alerts.map { |kind| [ d, kind ] } }

    # Rain minus evapotranspiration over the days shown (mm): below zero the soil dries.
    def balance
      return if days.empty?

      (days.sum { |d| d.rain.to_f } - days.sum { |d| d.et.to_f }).round
    end

    private

    # [{ at: local Time, "t_2m:C" => 12.3, ... }] one per hour.
    def hours
      @hours ||= begin
        times = @series.values.first.to_a.map(&:first)
        times.each_with_index.map do |time, i|
          @series.each_with_object({ at: time + @offset }) { |(parameter, values), row| row[parameter] = values.dig(i, 1) }
        end
      end
    end

    def values(list, parameter) = list.filter_map { |h| h[parameter] }
    def min(list, parameter) = values(list, parameter).min&.round(1)
    def max(list, parameter) = values(list, parameter).max&.round(1)
    def sum(list, parameter) = (v = values(list, parameter)).any? ? v.sum.round(1) : nil
  end
end
