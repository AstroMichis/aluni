# frozen_string_literal: true

module Weather
  # How thirsty the plants at a field's pin have been, from NASA ECOSTRESS on
  # the International Space Station (ECO_L4T_ESI: the evaporative stress index,
  # actual over potential evapotranspiration, 70 m) through AppEEARS. ESI near
  # 1 is a canopy using all the water it could; under STRESSED it is short of
  # water. The station passes at irregular hours and days, so a month holds a
  # few clear readings at most, and some months none.
  #
  # .summarize builds the "ecostress" observation's payload from the results
  # CSV (clear readings only: cloud mask 0); .new reads it back.
  class WaterStress
    SOURCE = "NASA ECOSTRESS"
    STRESSED = 0.3
    YEARS = 3
    RECENT = 12

    Month = Struct.new(:month, :esi, :readings, keyword_init: true) do
      def label_date = Date.strptime(month, "%Y-%m")
      def stressed? = esi && esi < STRESSED
    end

    def self.window(today: Date.current)
      last = today.prev_month.end_of_month
      [ last.beginning_of_month << ((YEARS * 12) - 1), last ]
    end

    def self.summarize(csv_text)
      readings = Appeears::Csv.rows(csv_text, esi: "_ESI", cloud: "_cloud").select do |r|
        r[:esi]&.finite? && r[:esi].between?(0, 1) && r[:cloud]&.round&.zero?
      end
      return {} if readings.empty?

      months = readings.group_by { |r| r[:at].strftime("%Y-%m") }.sort.map do |key, list|
        { "month" => key, "esi" => (list.sum { |r| r[:esi] } / list.size).round(2), "readings" => list.size }
      end
      normal = (1..12).to_h do |m|
        values = months.select { |row| row["month"].end_with?(format("-%02d", m)) }.map { |row| row["esi"] }
        [ m.to_s, values.any? ? (values.sum / values.size).round(2) : nil ]
      end
      recent = months.select { |row| row["month"] >= (readings.last[:at].to_date << (RECENT - 1)).strftime("%Y-%m") }
      latest = readings.last
      {
        "from" => readings.first[:at].to_date.iso8601, "to" => latest[:at].to_date.iso8601, "readings" => readings.size,
        "months" => recent, "normal" => normal,
        "latest" => { "date" => latest[:at].to_date.iso8601, "esi" => latest[:esi].round(2) },
        "stressed_months" => recent.select { |row| row["esi"] < STRESSED }.map { |row| row["month"] },
        "source" => SOURCE
      }
    end

    def initialize(observation)
      @payload = observation&.ok? ? observation.payload.to_h : {}
    end

    def present? = months.any?

    def months
      @months ||= Array(@payload["months"]).map { |m| Month.new(month: m["month"], esi: m["esi"], readings: m["readings"]) }
    end

    def stressed_months = months.select(&:stressed?)
    def latest = @payload["latest"]
  end
end
