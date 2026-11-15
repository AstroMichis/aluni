# frozen_string_literal: true

# V1 · Is the NASA data at the pin factual?
#
# Aluni reads NASA POWER (about 50 km cells) and GPM IMERG (about 10 km) at a field's pin. Here they are
# scored against two independent records for 2001-2025: Daymet (1 km grid interpolated from weather
# stations) and the CoCoRaHS volunteer rain gauges within 30 km of the pin.
#
# Pre-registered criterion (written before the results were seen):
#   PASS when daily Tmax and Tmin RMSE against Daymet are both <= 2.5 C, AND the May-Sep season rain of
#   POWER is within +-15% of the gauge mean (Daymet when no gauges) in at least 80% of the years.
#   Heavy-rain days (>= 25 mm) are reported as hit rate and false-alarm ratio, not scored, because the
#   app uses them as 20-year frequencies, not as day-by-day forecasts.
#
# Run: mise exec -- ruby docs/proposal/validation/v1_data.rb

require_relative "lib"
include Hindcast

power = power_daily
dm = daymet
days = power.keys.select { |d| dm[d] && power[d][:tmax] && power[d][:tmin] }

heading "Temperature: NASA POWER against Daymet (#{days.first}..#{days.last}, #{days.size} days)"
temp = %i[tmax tmin].to_h do |k|
  a = days.map { |d| power[d][k] }
  b = days.map { |d| dm[d][k] }
  stats = { rmse: rmse(a, b).round(2), bias: bias(a, b).round(2), r: pearson(a, b).round(3) }
  puts "#{k}: RMSE #{stats[:rmse]} C, bias #{stats[:bias]} C, r #{stats[:r]}"
  [ k, stats ]
end
frost = days.select { |d| (4..5).cover?(d.month) }
frost_agree = frost.count { |d| (power[d][:tmin] <= 0) == (dm[d][:tmin] <= 0) }
puts "Frost-day agreement in April-May (Tmin <= 0 in both or neither): #{(100.0 * frost_agree / frost.size).round(1)}%"

# CoCoRaHS: 7 am reports of the 24 h before, in inches ("T" trace = 0). Mean of the gauges reporting each day.
gauges = {}
stations = Hash.new(0)
Dir[path("cocorahs/*.csv")].each do |file|
  CSV.foreach(file, headers: true, header_converters: ->(h) { h.strip }) do |r|
    amount = r["TotalPrecipAmt"].to_s.strip
    next if amount.empty? || amount == "NA"

    mm = amount == "T" ? 0.0 : Float(amount, exception: false)&.*(25.4)
    next unless mm

    day = Date.parse(r["ObservationDate"]) - 1 # the rain fell mostly on the day before the 7 am reading
    (gauges[day] ||= []) << mm
    stations[r["StationName"].to_s.strip] += 1
  end
end
gauge = gauges.transform_values { |v| mean(v) }

heading "Season rain (May-Sep): POWER and IMERG against gauges and Daymet"
truth_label = gauge.any? ? "CoCoRaHS gauges (#{stations.size} stations within 30 km)" : "Daymet (no gauge file yet)"
years = (2001..2025).to_a
season = years.filter_map do |y|
  ds = (Date.new(y, 5, 1)..Date.new(y, 9, 30)).to_a
  gauge_days = ds.count { |d| gauge[d] }
  truth = gauge_days >= 0.9 * ds.size ? ds.sum { |d| gauge[d].to_f } : (gauge.any? ? nil : ds.sum { |d| dm[d]&.dig(:rain).to_f })
  next unless truth

  pw = ds.sum { |d| power[d][:rain].to_f }
  im = ds.sum { |d| imerg[d].to_f }
  { year: y, truth: truth.round, power: pw.round, imerg: im.round, daymet: ds.sum { |d| dm[d]&.dig(:rain).to_f }.round,
    power_err: (100 * (pw - truth) / truth).round(1), imerg_err: (100 * (im - truth) / truth).round(1) }
end
season.each { |s| puts "#{s[:year]}  truth #{s[:truth]}  POWER #{s[:power]} (#{s[:power_err]}%)  IMERG #{s[:imerg]} (#{s[:imerg_err]}%)  Daymet #{s[:daymet]}" }
within = season.count { |s| s[:power_err].abs <= 15 }
share = season.empty? ? nil : (100.0 * within / season.size).round
puts "POWER within +-15% in #{within} of #{season.size} seasons (#{share}%); IMERG within +-15% in #{season.count { |s| s[:imerg_err].abs <= 15 }}"

heading "Heavy-rain days (>= 25 mm), matched within one day"
truth_series = gauge.any? ? gauge : dm.transform_values { |v| v[:rain] }
heavy = { "POWER" => power.transform_values { |v| v[:rain].to_f }, "IMERG" => imerg }.to_h do |name, series|
  truth_days = truth_series.select { |d, mm| mm >= 25 && series.key?(d) }.keys
  model_days = series.select { |d, mm| mm >= 25 && truth_series.key?(d) }.keys
  hits = truth_days.count { |d| [ d - 1, d, d + 1 ].any? { |x| series[x].to_f >= 25 } }
  false_alarms = model_days.count { |d| [ d - 1, d, d + 1 ].none? { |x| truth_series[x].to_f >= 25 } }
  r = { truth_days: truth_days.size, model_days: model_days.size, hit_rate: truth_days.empty? ? nil : (100.0 * hits / truth_days.size).round,
        false_alarm_ratio: model_days.empty? ? nil : (100.0 * false_alarms / model_days.size).round }
  puts "#{name}: #{r[:truth_days]} heavy days in the truth, #{r[:model_days]} in #{name}; hit rate #{r[:hit_rate]}%, false alarms #{r[:false_alarm_ratio]}%"
  [ name, r ]
end

temp_pass = temp.values.all? { |s| s[:rmse] <= 2.5 }
rain_pass = share && share >= 80
pass = gauge.any? ? (temp_pass && rain_pass) : nil
record("V1",
       question: "Is the NASA data at the pin factual?",
       truth: "Daymet 1 km (temperature); #{truth_label} (rain)",
       criterion: "Tmax and Tmin RMSE <= 2.5 C vs Daymet; May-Sep rain within +-15% of the gauges in >= 80% of years",
       verdict: gauge.any? ? verdict(pass) : "BLOCKED (temperature #{verdict(temp_pass)}; rain needs the CoCoRaHS refetch)",
       summary: "Tmax RMSE #{temp[:tmax][:rmse]} C, Tmin RMSE #{temp[:tmin][:rmse]} C; season rain within 15% in #{share}% of years against #{truth_label}",
       details: { temperature: temp, frost_agreement_pct: (100.0 * frost_agree / frost.size).round(1), seasons: season, heavy_days: heavy,
                  gauges: stations.size })
