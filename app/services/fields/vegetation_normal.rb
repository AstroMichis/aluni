# frozen_string_literal: true

module Fields
  # What is usual for a field's spot, from NASA MODIS (Terra MOD13Q1: NDVI
  # every 16 days at 250 m since 2000) through AppEEARS: the median NDVI of
  # each calendar month over the past years, and the last 12 months against
  # it. It puts Fields::Vegetation's last year (Landsat and Sentinel-2, 30 m)
  # in context: a bare month that is usual there is the field's rhythm, one
  # far below normal is a change worth a look.
  #
  # .summarize builds the "modis" observation's payload from the results CSV;
  # .new reads it back. 250 m mixes the field with its neighbours.
  class VegetationNormal
    SOURCE = "NASA MODIS (Terra)"
    RELIABLE = [ 0, 1 ].freeze # pixel reliability: good, or marginal but usable
    RECENT = 12
    GAP = 0.1                  # NDVI points from the normal that count as below or above it

    def self.window(today: Date.current)
      [ Date.new(2001, 1, 1), today.prev_month.end_of_month ]
    end

    def self.summarize(csv_text)
      readings = Appeears::Csv.rows(csv_text, ndvi: "_250m_16_days_NDVI", reliability: "_250m_16_days_pixel_reliability").select do |r|
        r[:ndvi]&.finite? && r[:ndvi].between?(-0.2, 1) && RELIABLE.include?(r[:reliability]&.round)
      end
      return {} if readings.empty?

      by_month = readings.group_by { |r| r[:at].strftime("%Y-%m") }.transform_values { |list| list.sum { |r| r[:ndvi] } / list.size }
      recent_keys = by_month.keys.sort.last(RECENT)
      past = by_month.except(*recent_keys)
      normal = (1..12).to_h do |m|
        values = past.select { |key, _| key.end_with?(format("-%02d", m)) }.values
        [ m.to_s, values.any? ? median(values).round(3) : nil ]
      end
      recent = recent_keys.map do |key|
        usual = normal[key[5, 2].to_i.to_s]
        { "month" => key, "ndvi" => by_month[key].round(3), "normal" => usual,
          "anomaly" => usual && (by_month[key] - usual).round(3) }
      end
      known = normal.compact
      {
        "from" => readings.first[:at].to_date.iso8601, "to" => readings.last[:at].to_date.iso8601,
        "years" => past.keys.map { |k| k[0, 4] }.uniq.size,
        "normal" => normal, "recent" => recent,
        "peak_month" => known.max_by(&:last)&.first&.to_i, "low_month" => known.min_by(&:last)&.first&.to_i,
        "below" => recent.select { |r| r["anomaly"] && r["anomaly"] <= -GAP }.map { |r| r["month"] },
        "above" => recent.select { |r| r["anomaly"] && r["anomaly"] >= GAP }.map { |r| r["month"] },
        "source" => SOURCE
      }
    end

    def self.median(values)
      sorted = values.sort
      mid = sorted.size / 2
      sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
    end
    private_class_method :median

    def initialize(observation)
      @payload = observation&.ok? ? observation.payload.to_h : {}
    end

    def present? = @payload["normal"].to_h.values.any?

    # The usual NDVI for a "YYYY-MM" month, or nil.
    def normal_for(month) = @payload["normal"].to_h[month.to_s[5, 2].to_i.to_s]

    def below = Array(@payload["below"])
    def above = Array(@payload["above"])
    def years = @payload["years"]
    def peak_month = @payload["peak_month"]
    def low_month = @payload["low_month"]
  end
end
