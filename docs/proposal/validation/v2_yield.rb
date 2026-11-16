# frozen_string_literal: true

# V2 · Would Aluni's water model have flagged the bad years?
#
# For every season 2001-2025, the worked example's chain (FAO-56 ET0 with the day's NASA POWER wind ->
# Kc curve -> CROPWAT effective rain -> soil buffer -> FAO-33 yield factor) is run for corn and
# soybean. Nothing is fitted: every coefficient comes from the FAO tables, so this is a true out-of-sample
# test. The modelled yield factor is then scored against what happened in the site's county (sites.yml):
#   - NASS county yields, detrended by a straight line over 2001-2025 (the anomaly in %);
#   - USDA RMA insured losses by cause (drought + heat vs everything else), rank-correlated.
#
# Pre-registered criterion: PASS for a crop when Pearson r >= 0.5 between the modelled yield factor
# and the detrended NASS yield anomaly, AND 2012 (the 2012 drought) is among the three lowest modelled
# years. Misses are listed with the insurance cause that explains them.
#
# Rain source: the app reads NASA POWER rain; V1 found it about 16% low here, so the model also runs on
# IMERG (NASA, the app's storm source) and on Daymet (station-based) to show how much the choice matters.
#
# Run: mise exec -- ruby docs/proposal/validation/v2_yield.rb

require_relative "lib"
include Hindcast

YEARS = (2001..2025).to_a
CROPS = { CORN => "0041", SOY => "0081" }.freeze

power = power_daily
et0s = et0_series
# The app's rule since the backtest (U-27, U-28): IMERG rain and the state's NASS planting month.
CALENDAR = YAML.safe_load_file(File.join(ROOT, "config/crops/planting_calendars.yml")).dig("US", SITE["state_name"]) || {}
# name => [daily rain, planting month or nil for the FAO-56 row]
rain_sources = {
  "POWER" => [ power.transform_values { |v| v[:rain].to_f }, nil ],
  "IMERG" => [ imerg, nil ],
  "Daymet" => [ daymet.transform_values { |v| v[:rain] }, nil ],
  "App rule" => [ imerg, :calendar ]
}

# NASS county yields (bu/acre) in the series sites.yml prefers (non-irrigated first where it exists), or nil.
nass_series = CROPS.keys.to_h { |k| [ k, nass_yields(k) ] }
nass = nass_series.values.any? { |series, _| series.any? } ? nass_series.transform_values(&:first) : nil
nass_series.each { |k, (series, desc)| puts "NASS #{k}: #{desc || 'none'} (#{series.size} years)" }

# RMA indemnity in the site's county by year and cause group.
rma_by_year = YEARS.to_h do |y|
  rows = rma(y).select { |r| r[:county_code].to_i == SITE["county_fips"].to_i }
  [ y, CROPS.to_h do |k, code|
    crop_rows = rows.select { |r| r[:commodity_code] == code }
    group = crop_rows.group_by { |r| r[:cause].to_s.downcase }.transform_values { |rs| rs.sum { |r| r[:indemnity] } }
    dry = group.select { |c, _| c.match?(/drought|heat/) }.values.sum
    weather = group.reject { |c, _| c.match?(/price|arpi|area|other|all other/) }
    [ k, { drought_heat: dry.round, top_cause: weather.max_by(&:last)&.first, top_amount: weather.values.max.to_i, by_cause: group.transform_values(&:round) } ]
  end ]
end

results = {}
CROPS.each_key do |crop|
  heading "#{crop == CORN ? 'Corn' : 'Soybean'}: modelled yield factor by rain source vs #{SITE['county_name']} County records"
  model = rain_sources.to_h do |name, (rain, planting)|
    month = planting == :calendar ? CALENDAR.dig(crop, "planting_month") : nil
    [ name, YEARS.to_h do |y|
      need = season_need(crop, y, et0s, rain, planting: month)
      [ y, need && { factor: yield_factor(crop, need).round(3), factor_deep: yield_factor(crop, need, zr: ZR_MAX[crop]).round(3), deficit: need[:deficit_mm].round } ]
    end ]
  end

  anomaly = nil
  if nass && nass[crop].size >= 15
    ys = YEARS.select { |y| nass[crop][y] }
    a, b = linear_fit(ys, ys.map { |y| nass[crop][y] })
    anomaly = ys.to_h { |y| [ y, (100 * (nass[crop][y] - (a + (b * y))) / (a + (b * y))).round(1) ] }
  end

  puts "year  NASS bu/ac  anomaly%  | factor POWER  IMERG  Daymet  App   | RMA drought+heat $  top weather cause"
  YEARS.each do |y|
    r = rma_by_year[y][crop]
    printf("%d  %9s  %8s  |      %5s  %5s  %6s  %5s | %17s  %s\n", y, nass&.dig(crop, y) || "-", anomaly&.dig(y) || "-",
           *rain_sources.keys.map { |n| model[n][y]&.dig(:factor) || "-" }, r[:drought_heat], "#{r[:top_cause]} ($#{r[:top_amount]})")
  end

  scored = rain_sources.keys.to_h do |name|
    ys = YEARS.select { |y| model[name][y] && anomaly&.key?(y) }
    fac = ys.map { |y| model[name][y][:factor] }
    r = anomaly && ys.size >= 10 ? pearson(fac, ys.map { |y| anomaly[y] }) : nil
    lowest3 = YEARS.select { |y| model[name][y] }.min_by(3) { |y| model[name][y][:factor] }
    rma_ys = YEARS.select { |y| model[name][y] }
    rho = spearman(rma_ys.map { |y| 1 - model[name][y][:factor] }, rma_ys.map { |y| rma_by_year[y][crop][:drought_heat] })
    rho_p = permutation_p(rma_ys.map { |y| 1 - model[name][y][:factor] }, rma_ys.map { |y| rma_by_year[y][crop][:drought_heat] }, stat: :spearman)
    p_r = r && permutation_p(fac, ys.map { |y| anomaly[y] })
    out = { pearson_vs_nass: r&.round(2), p_value: p_r&.round(4), n: ys.size, lowest3: lowest3, flags_2012: lowest3.include?(2012),
            spearman_vs_rma_drought: rho&.round(2), rma_p_value: rho_p.round(4),
            stressed_years: YEARS.select { |y| model[name][y] && model[name][y][:factor] < 0.999 } }
    puts "#{name.ljust(6)} r vs NASS anomaly #{out[:pearson_vs_nass] || 'n/a (NASS not fetched)'}#{" (p=#{out[:p_value]})" if p_r}; " \
         "rank corr. with RMA drought+heat losses #{out[:spearman_vs_rma_drought]} (p=#{out[:rma_p_value]}); 3 lowest modelled years #{lowest3.inspect}; " \
         "years with any stress: #{out[:stressed_years].size}"
    [ name, out ]
  end

  # "Flagged" = among the lowest quarter of modelled years (a threshold on the factor itself flags almost every year).
  quartile = YEARS.select { |y| model["POWER"][y] }.min_by((YEARS.size / 4.0).ceil) { |y| model["POWER"][y][:factor] }
  misses = anomaly ? anomaly.select { |_, v| v <= -10 }.keys.reject { |y| quartile.include?(y) } : []
  false_alarms = anomaly ? quartile.select { |y| anomaly[y] && anomaly[y] > 0 } : []
  puts "Lowest-quarter modelled years: #{quartile.sort.inspect}; of them above trend in reality: #{false_alarms.inspect}"
  if anomaly
    deep = YEARS.select { |y| model["POWER"][y] && anomaly.key?(y) }
    r_deep = pearson(deep.map { |y| model["POWER"][y][:factor_deep] }, deep.map { |y| anomaly[y] })
    puts "With the FAO-56 maximum root depth (#{ZR_MAX[crop]} m): r vs NASS anomaly #{r_deep&.round(2)}; years with any stress #{deep.count { |y| model["POWER"][y][:factor_deep] < 0.999 }}"
  end
  explained = misses.to_h { |y| [ y, rma_by_year[y][crop][:top_cause] ] }
  puts "Bad years (NASS anomaly <= -10%) the water model did not flag: #{explained.empty? ? '-' : explained.map { |y, c| "#{y} (#{c || 'no insured loss'})" }.join(', ')}"

  y2025 = { model_power: model["POWER"][2025], model_daymet: model["Daymet"][2025], nass_anomaly: anomaly&.dig(2025), rma: rma_by_year[2025][crop][:by_cause] }
  puts "2025: modelled factor #{y2025[:model_power]&.dig(:factor)} (POWER rain), #{y2025[:model_daymet]&.dig(:factor)} (Daymet rain), " \
       "deep roots #{y2025[:model_power]&.dig(:factor_deep)}; NASS anomaly #{y2025[:nass_anomaly] || 'n/a'}%; RMA causes #{y2025[:rma].reject { |_, v| v.zero? }}"
  pass = anomaly ? (scored["POWER"][:pearson_vs_nass].to_f >= 0.5 && scored["POWER"][:flags_2012]) : nil
  results[crop] = { verdict: verdict(pass), scored: scored, misses: explained, lowest_quarter: quartile, false_alarms: false_alarms,
                    r_deep_roots: (anomaly && r_deep&.round(2)), y2025: y2025, model: model, nass_anomaly: anomaly }
end

summary = results.map do |crop, r|
  s = r[:scored]["POWER"]
  "#{crop == CORN ? 'corn' : 'soybean'} #{r[:verdict]}: r=#{s[:pearson_vs_nass] || 'n/a'} vs NASS, 2012 #{s[:flags_2012] ? 'flagged' : 'missed'}, rho=#{s[:spearman_vs_rma_drought]} vs RMA drought"
end.join("; ")
verdicts = results.values.map { |r| r[:verdict] }.uniq
record("V2",
       question: "Would the water model have flagged the bad years?",
       truth: "NASS #{SITE['county_name']} County yields (detrended), USDA RMA insured losses by cause, 2001-2025",
       criterion: "Pearson r >= 0.5 vs detrended yield anomaly and 2012 among the 3 lowest modelled years, per crop (app's POWER rain)",
       verdict: verdicts.size == 1 ? verdicts.first : verdicts.join("/"),
       summary: summary,
       details: results.transform_values { |r| r.except(:model) }.merge(rma_by_year: rma_by_year))
