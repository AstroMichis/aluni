# frozen_string_literal: true

module Weather
  # Root-zone soil moisture (0-100 cm) at a field's pin over the last year from
  # NASA SMAP L4 (SPL4SMGP: the SMAP radiometer assimilated into a land model,
  # 9 km, 3-hourly, no gaps), read from the AppEEARS results CSV that
  # Fields::FetchSoilMoistureJob downloads.
  #
  # .summarize keeps one row per month (mean volumetric moisture and mean
  # percentile against the product's own climatology), the latest value, and
  # the dry months (mean percentile under DRY_PCTL: the driest fifth of what
  # is usual there) and wet ones. .new reads the "smap" observation back.
  # Regional context, not a soil probe: one 9 km cell mixes irrigated and
  # dry land.
  class SoilMoisture
    DRY_PCTL = 20
    WET_PCTL = 80
    MONTHS = 12
    FILL = -9999
    SOURCE = "NASA SMAP L4"

    Month = Struct.new(:month, :rootzone, :pctl, keyword_init: true) do
      def label_date = Date.strptime(month, "%Y-%m")
      def dry? = pctl && pctl < DRY_PCTL
      def wet? = pctl && pctl > WET_PCTL
    end

    # The last 12 full months before `today` (L4 is a few days behind).
    def self.window(today: Date.current)
      last = today.prev_month.end_of_month
      [ last.beginning_of_month << (MONTHS - 1), last ]
    end

    # The AppEEARS SPL4SMGP results CSV => the observation payload, or {} without values.
    def self.summarize(csv_text)
      lines = csv_text.to_s.lines.map { |line| fields(line.chomp) }
      headers = lines.shift.to_a
      date_col = headers.index("Date")
      rootzone_col = headers.index { |h| h.end_with?("_sm_rootzone") }
      pctl_col = headers.index { |h| h.end_with?("_sm_rootzone_pctl") }
      return {} unless date_col && rootzone_col

      readings = lines.filter_map do |row|
        value = Float(row[rootzone_col].to_s, exception: false)
        at = Time.zone.parse(row[date_col].to_s) rescue nil
        next if at.nil? || value.nil? || value <= FILL || value.negative?

        pctl = pctl_col && Float(row[pctl_col].to_s, exception: false)
        [ at, value, pctl&.between?(0, 100) ? pctl : nil ]
      end
      return {} if readings.empty?

      months = readings.group_by { |(at, _, _)| at.strftime("%Y-%m") }.sort.map do |month, list|
        pctls = list.filter_map(&:last)
        { "month" => month, "rootzone" => mean(list.map { |r| r[1] }, 3), "pctl" => pctls.any? ? mean(pctls, 0) : nil }
      end
      latest = readings.max_by(&:first)
      {
        "from" => readings.map(&:first).min.to_date.iso8601, "to" => latest.first.to_date.iso8601,
        "months" => months,
        "latest" => { "date" => latest.first.to_date.iso8601, "rootzone" => latest[1].round(3), "pctl" => latest[2]&.round },
        "dry_months" => months.select { |m| m["pctl"] && m["pctl"] < DRY_PCTL }.map { |m| m["month"] },
        "wet_months" => months.select { |m| m["pctl"] && m["pctl"] > WET_PCTL }.map { |m| m["month"] },
        "source" => SOURCE
      }
    end

    def self.mean(values, digits) = (values.sum / values.size.to_f).round(digits)

    # One CSV line into its fields, honouring double quotes (the stdlib csv
    # is a separate gem since Ruby 3.4, and these files are plain).
    def self.fields(line)
      out = [ +"" ]
      quoted = false
      chars = line.chars
      i = 0
      while i < chars.size
        c = chars[i]
        if c == '"' && quoted && chars[i + 1] == '"' then out.last << '"'; i += 1
        elsif c == '"' then quoted = !quoted
        elsif c == "," && !quoted then out << +""
        else out.last << c
        end
        i += 1
      end
      out
    end
    private_class_method :mean, :fields

    def initialize(observation)
      @payload = observation&.ok? ? observation.payload.to_h : {}
    end

    def present? = months.any?

    def months
      @months ||= Array(@payload["months"]).map { |m| Month.new(month: m["month"], rootzone: m["rootzone"], pctl: m["pctl"]) }
    end

    def dry_months = months.select(&:dry?)
    def wet_months = months.select(&:wet?)
    def latest = @payload["latest"]
  end
end
