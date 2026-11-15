# frozen_string_literal: true

module Weather
  # How often it pours at a field's pin, from 20 full years of NASA GPM IMERG
  # daily rain (NasaPower::Client#imerg_daily, 0.1°, about 10 km): heavy days
  # (25 mm or more, the same line as Weather::Season) and extreme days (50 mm
  # or more) per year and per calendar month, the wettest day, the 99th
  # percentile of rainy days and the longest dry spell of each year.
  #
  # .summarize builds the "gpm_imerg" observation's payload from the daily
  # series; .new reads it back for the rotation plan (storm-prone months raise
  # the erosion risk of row crops). Regional context, not a rain gauge.
  class RainExtremes
    HEAVY_MM = Season::HEAVY_RAIN_MM
    EXTREME_MM = 50.0
    WET_MM = Season::DRY_DAY_MM
    YEARS = 20
    STORMY_MONTH = 1.0   # heavy days a year, on average, from which a month is storm-prone
    STORMY_FIELD = 1.0   # extreme days a year from which bare soil is at risk of washing
    SOURCE = "NASA GPM IMERG"

    Month = Struct.new(:month, :rain_mm, :heavy_days, :extreme_days, :max_mm, keyword_init: true) do
      def stormy? = heavy_days.to_f >= STORMY_MONTH
    end

    # The last YEARS full calendar years before `today`.
    def self.window(today: Date.current)
      last = today.year - 1
      [ Date.new(last - YEARS + 1, 1, 1), Date.new(last, 12, 31) ]
    end

    # { "20060101" => 3.2, ... } (mm/day, nil for a missing day) => the payload, or {} with no values.
    def self.summarize(daily)
      days = daily.to_h.filter_map { |key, mm| [ Date.strptime(key, "%Y%m%d"), mm.to_f ] unless mm.nil? }.sort_by(&:first)
      return {} if days.empty?

      years = days.map { |(d, _)| d.year }.uniq.size
      wet = days.map(&:last).select { |mm| mm >= WET_MM }.sort
      wettest = days.max_by(&:last)
      {
        "from" => days.first.first.iso8601, "to" => days.last.first.iso8601, "years" => years,
        "heavy_mm" => HEAVY_MM, "extreme_mm" => EXTREME_MM,
        "heavy_days_per_year" => per_year(days.count { |(_, mm)| mm >= HEAVY_MM }, years),
        "extreme_days_per_year" => per_year(days.count { |(_, mm)| mm >= EXTREME_MM }, years),
        "p99_mm" => wet.any? ? wet[((wet.size - 1) * 0.99).round].round(1) : nil,
        "wettest" => { "date" => wettest.first.iso8601, "mm" => wettest.last.round(1) },
        "dry_spell" => dry_spell(days),
        "months" => (1..12).map { |m| month_row(m, days.select { |(d, _)| d.month == m }, years) },
        "source" => SOURCE
      }
    end

    def self.per_year(count, years) = (count / years.to_f).round(1)

    def self.month_row(month, days, years)
      {
        "month" => month, "rain_mm" => (days.sum(&:last) / years).round,
        "heavy_days" => per_year(days.count { |(_, mm)| mm >= HEAVY_MM }, years),
        "extreme_days" => per_year(days.count { |(_, mm)| mm >= EXTREME_MM }, years),
        "max_mm" => (days.map(&:last).max || 0).round(1)
      }
    end

    # The longest run of days under WET_MM in each year: its median and the worst.
    def self.dry_spell(days)
      longest = days.group_by { |(d, _)| d.year }.values.map do |year|
        year.chunk_while { |(_, a), (_, b)| a < WET_MM && b < WET_MM }.select { |run| run.first.last < WET_MM }.map(&:size).max || 0
      end.sort
      { "median_days" => longest[longest.size / 2], "max_days" => longest.last }
    end
    private_class_method :per_year, :month_row, :dry_spell

    def initialize(observation)
      @payload = observation&.ok? ? observation.payload.to_h : {}
    end

    def present? = months.any?

    def months
      @months ||= Array(@payload["months"]).map do |row|
        Month.new(month: row["month"], rain_mm: row["rain_mm"], heavy_days: row["heavy_days"],
                  extreme_days: row["extreme_days"], max_mm: row["max_mm"])
      end
    end

    def stormy_months = months.select(&:stormy?)
    def heavy_days_per_year = @payload["heavy_days_per_year"]
    def extreme_days_per_year = @payload["extreme_days_per_year"]
    def stormy_field? = extreme_days_per_year.to_f >= STORMY_FIELD
    def wettest = @payload["wettest"]
    def years = @payload["years"]
    def period = @payload.values_at("from", "to").map { |d| d && Date.iso8601(d).year }
  end
end
