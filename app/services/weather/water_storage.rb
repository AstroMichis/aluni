# frozen_string_literal: true

module Weather
  # The region's water bank from NASA GRACE and GRACE-FO (Grace::Client): all
  # the water in and on the ground (groundwater, soil moisture, snow, lakes and
  # rivers) as a thickness in cm against its 2004-2009 mean. A region about
  # 300 km wide: it tells whether wells, canals and reservoirs draw on a
  # shrinking store, not what one field holds.
  #
  # .summarize keeps the last 12 months' mean against the baseline, the trend
  # over the last 10 years, each year's mean and the lowest year; .new reads
  # the "grace" observation back.
  class WaterStorage
    SOURCE = "NASA GRACE / GRACE-FO"
    LOW_CM = -10.0  # a year's mean this far below 2004-2009 is a depleted store
    TREND_YEARS = 10

    def self.summarize(series)
      points = Array(series).filter_map { |date, cm| [ date.to_date, cm.to_f ] if date && cm }
      return {} if points.size < 24

      recent = points.last(12)
      years = points.group_by { |d, _| d.year }.transform_values { |list| (list.sum(&:last) / list.size).round(1) }
      cutoff = points.last.first << (TREND_YEARS * 12)
      {
        "from" => points.first.first.iso8601, "to" => points.last.first.iso8601, "months" => points.size,
        "recent_cm" => (recent.sum(&:last) / recent.size).round(1),
        "trend_cm_per_decade" => (slope(points.select { |d, _| d >= cutoff }) * 3652.5).round(1),
        "years" => years.transform_keys(&:to_s),
        "lowest" => years.min_by(&:last).then { |year, cm| { "year" => year, "cm" => cm } },
        "source" => SOURCE
      }
    end

    # Least-squares slope in cm per day.
    def self.slope(points)
      return 0.0 if points.size < 2

      xs = points.map { |d, _| d.jd.to_f }
      ys = points.map(&:last)
      mx = xs.sum / xs.size
      my = ys.sum / ys.size
      den = xs.sum { |x| (x - mx)**2 }
      den.zero? ? 0.0 : xs.zip(ys).sum { |x, y| (x - mx) * (y - my) } / den
    end
    private_class_method :slope

    def initialize(observation)
      @payload = observation&.ok? ? observation.payload.to_h : {}
    end

    def present? = !@payload["recent_cm"].nil?
    def recent_cm = @payload["recent_cm"]
    def trend = @payload["trend_cm_per_decade"]
    def lowest = @payload["lowest"]
    def depleted? = present? && recent_cm <= LOW_CM
  end
end
