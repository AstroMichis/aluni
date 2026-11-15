# frozen_string_literal: true

# V8 · Do the timeline's crop and bare months match what the satellites saw at the pin?
#
# Rotations::Timeline puts a crop in the ground from its FAO-56 planting month for ceil(days / 30.4)
# months (corn April-August, soybean May-September) and calls every other month bare. Here each year's
# CDL crop at the pin gets that predicted calendar, and it is scored against one clear-sky NDVI per month
# (Landsat + Sentinel-2, the app's own PlanetaryComputer::Client#monthly_ndvi), 2013-2025.
#
# Observed state: "crop cover" when NDVI >= 0.4, else "open soil" (a green canopy over the ground;
# 0.4 is the usual threshold for a closed row-crop canopy). Pre-registered criterion: PASS when the
# monthly agreement is >= 80% AND the predicted planting and harvest months are each within one month
# of the observed green-up (first month >= 0.4) and senescence (last month >= 0.4) in >= 80% of years.
#
# Run: mise exec -- ruby docs/proposal/validation/v8_timeline.rb

require_relative "lib"
include Hindcast

THRESHOLD = 0.4
need!("cdl.json")
cdl = JSON.parse(File.read(path("cdl.json"))).transform_keys(&:to_i)
key_of = { "Corn" => CORN, "Soybeans" => SOY }
years = Dir[path("ndvi/*.json")].map { |f| File.basename(f, ".json").to_i }.sort & cdl.keys
raise Blocked, "no NDVI years yet" if years.empty?

# Timeline#season_of with FAO-56 values (the CDL gives no planting dates).
predicted = lambda do |crop|
  fao = AGRONOMY.dig(crop, "fao56")
  first = fao["planting_month"]
  first...(first + (fao["stages"].sum / 30.4).ceil)
end

rows = []
seasons = years.filter_map do |y|
  crop = key_of[cdl[y]] or next
  obs = JSON.parse(File.read(path("ndvi/#{y}.json"))).to_h { |r| [ r["month"][5, 2].to_i, r["ndvi"] ] }
  grow = predicted.(crop)
  (1..12).each do |m|
    next if obs[m].nil?

    rows << { year: y, month: m, crop: cdl[y], predicted: grow.cover?(m) ? "crop" : "bare", observed: obs[m] >= THRESHOLD ? "crop" : "bare", ndvi: obs[m] }
  end
  green = (1..12).select { |m| obs[m] && obs[m] >= THRESHOLD }
  next if green.empty?

  { year: y, crop: cdl[y], planting: grow.first, harvest: grow.max, green_up: green.first, senescence: green.last,
    nov_dec: [ 11, 12 ].to_h { |m| [ m, obs[m] ] }, months_seen: obs.compact.size }
end

heading "Monthly agreement, predicted (FAO-56 calendar) vs observed (NDVI >= #{THRESHOLD})"
agree = rows.count { |r| r[:predicted] == r[:observed] }
by_month = (1..12).to_h do |m|
  rs = rows.select { |r| r[:month] == m }
  [ m, rs.empty? ? nil : { agree_pct: (100.0 * rs.count { |r| r[:predicted] == r[:observed] } / rs.size).round, n: rs.size,
                          mean_ndvi: mean(rs.map { |r| r[:ndvi] }).round(2) } ]
end
by_month.each { |m, s| puts "#{Date::ABBR_MONTHNAMES[m]}  #{s ? "agree #{s[:agree_pct]}% (n=#{s[:n]}), mean NDVI #{s[:mean_ndvi]}" : 'no clear view'}" }
share = (100.0 * agree / rows.size).round
puts "Overall: #{agree} of #{rows.size} clear months agree (#{share}%)"
wrong = rows.reject { |r| r[:predicted] == r[:observed] }.group_by { |r| [ r[:predicted], r[:observed] ] }.transform_values(&:size)
puts "Disagreements: #{wrong.map { |(p, o), n| "predicted #{p}, saw #{o}: #{n}" }.join('; ')}"

heading "Season edges: predicted planting and harvest vs observed green-up and senescence"
seasons.each do |s|
  puts "#{s[:year]} #{s[:crop].ljust(8)} planted #{Date::ABBR_MONTHNAMES[s[:planting]]} -> green #{Date::ABBR_MONTHNAMES[s[:green_up]]}; " \
       "harvest #{Date::ABBR_MONTHNAMES[s[:harvest]]} -> senescent after #{Date::ABBR_MONTHNAMES[s[:senescence]]}"
end
edge_ok = seasons.count { |s| (s[:green_up] - s[:planting]).abs <= 1 && (s[:senescence] - s[:harvest]).abs <= 1 }
edge_share = seasons.empty? ? 0 : (100.0 * edge_ok / seasons.size).round
lag = seasons.empty? ? nil : mean(seasons.map { |s| s[:green_up] - s[:planting] }).round(1)
puts "Both edges within one month in #{edge_ok} of #{seasons.size} seasons (#{edge_share}%); mean lag from planting to a green canopy #{lag} months"

nov_dec = seasons.flat_map { |s| s[:nov_dec].values.compact }
puts "Nov-Dec (unknown in the worked example): #{nov_dec.size} clear views, #{nov_dec.count { |v| v < THRESHOLD }} of them open soil (NDVI < #{THRESHOLD})"

# The rule the app uses since the backtest (U-28, U-29): plant in the region's calendar month
# (config/crops/planting_calendars.yml, NASS progress) and count the months before FAO-56 effective full
# cover (initial + development days) as open soil. Scored on the same clear months.
calendar = YAML.safe_load_file(File.join(ROOT, "config/crops/planting_calendars.yml")).dig("US", "Iowa") || {}
covered = lambda do |crop, m|
  fao = AGRONOMY.dig(crop, "fao56")
  first = calendar.dig(crop, "planting_month") || fao["planting_month"]
  k = m - first
  next false unless k >= 0 && k < (fao["stages"].sum / 30.4).ceil

  (k * 30.4) + 15.2 >= fao["stages"][0] + fao["stages"][1]
end
new_rows = rows.map { |r| r.merge(new_predicted: covered.(key_of[r[:crop]], r[:month]) ? "crop" : "bare") }
new_agree = new_rows.count { |r| r[:new_predicted] == r[:observed] }
new_share = (100.0 * new_agree / new_rows.size).round
heading "The app's rule since the backtest: NASS calendar planting + open soil until FAO-56 full cover"
puts "Monthly agreement: #{new_agree} of #{new_rows.size} (#{new_share}%), was #{share}% with the FAO-56 calendar"
(4..10).each do |m|
  rs = new_rows.select { |r| r[:month] == m }
  puts "#{Date::ABBR_MONTHNAMES[m]}  agree #{(100.0 * rs.count { |r| r[:new_predicted] == r[:observed] } / rs.size).round}% (was #{by_month[m]&.dig(:agree_pct)}%)" unless rs.empty?
end

pass = share >= 80 && edge_share >= 80
record("V8",
       question: "Do the timeline's crop and bare months match what the satellites saw?",
       truth: "Landsat + Sentinel-2 monthly NDVI at the pin (#{years.first}-#{years.last}) with the CDL crop of each year",
       criterion: "Monthly agreement >= 80% and both season edges within one month in >= 80% of years",
       verdict: verdict(pass),
       summary: "#{share}% of #{rows.size} clear months agree; edges within a month in #{edge_share}% of seasons; " \
                "a green canopy appears #{lag} months after the FAO-56 planting month on average",
       details: { by_month: by_month, disagreements: wrong.transform_keys { |k| k.join(' -> ') }, seasons: seasons, years: years,
                  agreement_pct: share, edges_pct: edge_share, lag_months: lag, nov_dec_open: nov_dec.count { |v| v < THRESHOLD }, nov_dec_views: nov_dec.size,
                  app_rule_agreement_pct: new_share })
