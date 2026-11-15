# frozen_string_literal: true

# Cross-check: the app's own services against the plain-Ruby worked example, on the same field.
# Feeds 2025 monthly means from farm_data_42.0_-93.75.csv into Weather::Et0.monthly, Crops::WaterNeed
# and Crops::RotationCheck, and prints them beside ames_worked_example_out.json. No network, no database.
#
# Run, after the worked example:
#   mise exec -- ruby docs/proposal/ames_worked_example.rb
#   mise exec -- bin/rails runner docs/proposal/ames_cross_check.rb
#
# Expected differences: the app works on monthly means (mean temperature only), the worked example on
# daily Tmax/Tmin, so the app's ET0 runs a little lower, most in winter; the app spreads a month's rain
# evenly over the season's days, the worked example uses the actual days.

out = JSON.parse(File.read(Rails.root.join("docs/proposal/ames_worked_example_out.json")))
d = Hash.new { |h, k| h[k] = {} }
# NASA POWER rows have no quoted commas; csv is not in the Gemfile.
File.foreach(Rails.root.join("farm_data_42.0_-93.75.csv")) do |line|
  source, variable, value, _, date = line.split(",")
  d[Date.parse(date)][variable] = value.to_f if source == "NASA POWER"
end
months = d.keys.map(&:month).uniq
map = { "T2M" => "air_temp_mean", "RH2M" => "relative_humidity", "ALLSKY_SFC_SW_DWN" => "solar_radiation", "PRECTOTCORR" => "precipitation" }
clim = map.to_h do |param, var|
  [ param, months.to_h { |m| sel = d.select { |k, _| k.month == m }.values; [ Weather::Season::MONTHS[m - 1], sel.sum { |x| x[var] } / sel.size ] } ]
end
# Wind: the measured NASA POWER WS2M monthly means when validation/fetch.rb has run (as the worked example
# uses), else the worked example's constant.
power_file = Rails.root.join("docs/proposal/validation/data/power_daily.json")
ws = File.exist?(power_file) ? JSON.parse(File.read(power_file)).dig("properties", "parameter", "WS2M").select { |k, v| k.start_with?("2025") && v > -999 } : {}
clim["WS2M"] = months.to_h do |m|
  days = ws.select { |k, _| k[4, 2].to_i == m }.values
  [ Weather::Season::MONTHS[m - 1], days.empty? ? 2.0 : days.sum / days.size ]
end
# Weather::Et0.monthly wants all twelve months. Padding only: no season below reaches the missing months.
last = Weather::Season::MONTHS[months.max - 1]
clim.each_value { |h| Weather::Season::MONTHS.each { |n| h[n] ||= h[last] } }
et0 = Weather::Et0.monthly(clim, latitude: out.dig("field", "lat"), elevation: out.dig("field", "elevation_m"))

puts "Weather::Et0.monthly vs daily FAO-56 (mm per month)"
months.each do |m|
  app = et0[m] * Time.days_in_month(m, 2025)
  script = out.dig("monthly", m.to_s, "et0")
  printf("%3d  app %6.1f  worked example %6.1f  %+5.1f%%\n", m, app, script, 100 * (app - script) / script)
end

puts "\nCrops::WaterNeed (mm over the season)"
app_needs = {}
out["need"].each_key do |key|
  fao = Crops::Agronomy.find(key).fao56
  app = app_needs[key] = Crops::WaterNeed.new(fao, et0, clim["PRECTOTCORR"], fao["planting_month"]).need
  ex = out["need"][key]
  printf("%-18s app ETc %4d eff %4d deficit %4d | worked example ETc %4d eff %4d deficit %4d\n",
         key, app.crop_mm, app.effective_mm, app.deficit_mm, ex["crop_mm"], ex["effective_mm"], ex["deficit_mm"])
end

puts "\nCrops::RotationCheck -> Comparator pest_break"
history = out.dig("field", "cdl").sort.last(2).map { |year, name| [ year, name ] }
out["compare"].each do |key, s|
  crops = s["crops"].map { |c| Crops::Agronomy.find(c).key }
  findings = Crops::RotationCheck.new(history + crops.each_with_index.map { |c, i| [ "+#{i + 1}", c ] }).findings
  app = [ 100 - (findings.count { |f| f.kind == "same_family" } * 25) - (findings.count { |f| f.kind == "monoculture" } * 30), 0 ].max
  puts "#{key.ljust(13)} app #{app}  worked example #{s.dig('scores', 'pest_break')}  #{app == s.dig('scores', 'pest_break') ? 'same' : 'DIFFERS'}"
end

# The strategy totals with the app's own water shares (Comparator#water: 100 x mean effective/crop over the
# seasons, rainfed) and the worked example's other five scores and weights, totalled as Comparator#total does.
puts "\nRotations::Comparator totals with the app's water shares"
out["compare"].each do |key, s|
  crops = s["crops"].map { |c| Crops::Agronomy.find(c).key }
  water = (100 * crops.sum { |c| app_needs[c].effective_mm / app_needs[c].crop_mm.to_f } / crops.size).clamp(0, 100).round
  scores = s["scores"].merge("water" => water)
  total = (scores.sum { |c, v| v * out["weights"][c] } / scores.keys.sum { |c| out["weights"][c] }.to_f).round
  puts "#{key.ljust(13)} water app #{water} worked example #{s.dig("scores", "water")}  total app #{total} worked example #{s["total"]}  #{total == s["total"] ? "same" : "DIFFERS"}"
end
