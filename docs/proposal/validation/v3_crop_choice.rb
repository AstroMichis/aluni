# frozen_string_literal: true

# V3 · Does Aluni's crop evidence point at the crops that actually thrive here?
#
# Aluni's crop fit reads FAO GAEZ v4 (1981-2010 climate, rainfed) and its water criterion reads the FAO-56
# water need. At the Ames pin these are compared with what the land shows: the crops grown (CDL 2008-2025)
# and the yields obtained (NASS Story County, and Iowa for wheat and other crops Story does not report).
#
# GAEZ attainable yield is dry weight; NASS reports grain at market moisture, so NASS is converted to dry
# weight with the standard moistures (corn 15.5%, soybeans 13%, wheat 13.5%, oats 14%) and bushel weights
# (corn 56 lb, soybeans and wheat 60 lb, oats 32 lb).
#
# Pre-registered criterion: PASS when (a) the crops GAEZ and the water model rank first are the ones grown
# (corn and soybean above wheat and sunflower), and (b) GAEZ high-input attainable yield is within +-30%
# of the NASS county mean for corn and soybean over 2001-2010 (the end of GAEZ's climate window).
#
# Run: mise exec -- ruby docs/proposal/validation/v3_crop_choice.rb

require_relative "lib"
include Hindcast

need!("gaez.json", "cdl.json")
gaez = JSON.parse(File.read(path("gaez.json")))
cdl = JSON.parse(File.read(path("cdl.json")))
GAEZ_NAME = { CORN => "Maize", SOY => "Soybean", WHEAT => "Wheat", SUN => "Sunflower" }.freeze
BUSHEL = { CORN => [ 56, 0.155 ], SOY => [ 60, 0.13 ], WHEAT => [ 60, 0.135 ] }.freeze # lb per bushel, market moisture
NASS_DESC = { CORN => "CORN, GRAIN - YIELD, MEASURED IN BU / ACRE", SOY => "SOYBEANS - YIELD, MEASURED IN BU / ACRE",
              WHEAT => "WHEAT - YIELD, MEASURED IN BU / ACRE" }.freeze
TO_KG_HA = 0.45359237 / 0.40468564 # lb/acre -> kg/ha

heading "What the land grew (CDL at the pin, 2008-2025)"
grown = cdl.values.tally
puts grown.map { |c, n| "#{c} #{n} years" }.join(", ")

heading "GAEZ v4 at the pin (rainfed, 1981-2010)"
gaez_rows = GAEZ_NAME.to_h do |key, name|
  h = gaez.dig("High", name) || {}
  l = gaez.dig("Low", name) || {}
  puts "#{name.ljust(10)} suitability high #{h['suitability']&.round} / low #{l['suitability']&.round}; attainable high #{h['attainable_yield']&.round} / low #{l['attainable_yield']&.round} kg DW/ha"
  [ key, { suit_high: h["suitability"], suit_low: l["suitability"], yield_high: h["attainable_yield"], yield_low: l["attainable_yield"] } ]
end
others = (gaez["High"] || {}).reject { |n, _| GAEZ_NAME.value?(n) }
puts "Also suitable here (high input): #{others.map { |n, v| "#{n} #{v['suitability']&.round}" }.join(', ')}"
distinguishes = gaez_rows.values.map { |r| r[:suit_high] }.uniq.size > 1
puts distinguishes ? "GAEZ suitability separates the crops." : "GAEZ high-input suitability is the same for every crop here: it cannot rank them; the low-input layer is the only one that does."

heading "Water model, 2001-2025 (mean modelled yield factor, POWER inputs as the app reads them)"
et0s = et0_series
rain = power_daily.transform_values { |v| v[:rain].to_f }
water = GAEZ_NAME.keys.to_h do |key|
  f = (2001..2025).filter_map { |y| (n = season_need(key, y, et0s, rain)) && yield_factor(key, n) }
  [ key, mean(f).round(3) ]
end
water.each { |k, v| puts "#{GAEZ_NAME[k].ljust(10)} mean yield factor #{v}" }

nass = if File.exist?(path("nass/yield_county.json"))
         rows = JSON.parse(File.read(path("nass/yield_county.json"))) +
                (File.exist?(path("nass/yield_state.json")) ? JSON.parse(File.read(path("nass/yield_state.json"))) : [])
         NASS_DESC.to_h do |k, desc|
           sel = rows.select { |r| r["short_desc"] == desc && r["reference_period_desc"] == "YEAR" }
           county = sel.select { |r| r["agg_level_desc"] == "COUNTY" }
           state = sel.select { |r| r["agg_level_desc"] == "STATE" }
           pick = county.any? ? county : state
           [ k, { level: county.any? ? "Story County" : "Iowa",
                 by_year: pick.filter_map { |r| (v = Float(r["Value"].to_s.delete(","), exception: false)) && [ r["year"].to_i, v ] }.to_h } ]
         end
end

checks = {}
if nass
  heading "GAEZ attainable yield vs NASS (dry weight, 2001-2010 mean)"
  BUSHEL.each do |key, (lb, moisture)|
    ys = nass[key][:by_year].select { |y, _| (2001..2010).cover?(y) }
    next if ys.empty?

    dw = mean(ys.values) * lb * TO_KG_HA * (1 - moisture)
    ga = gaez_rows[key][:yield_high]
    diff = ga && (100 * (ga - dw) / dw).round
    checks[key] = { nass_dw: dw.round, gaez: ga&.round, diff_pct: diff, level: nass[key][:level], years: ys.size }
    puts "#{GAEZ_NAME[key].ljust(8)} NASS #{nass[key][:level]} #{dw.round} kg DW/ha (#{ys.size} yrs) vs GAEZ #{ga&.round} -> #{diff}%"
  end
end

top_water = water.max_by(2, &:last).map(&:first)
grown_keys = grown.keys.map { |c| { "Corn" => CORN, "Soybeans" => SOY }[c] }.compact
rank_ok = (grown_keys - top_water).empty?
yield_ok = checks.slice(CORN, SOY).values.all? { |c| c[:diff_pct] && c[:diff_pct].abs <= 30 } && checks.key?(CORN) && checks.key?(SOY)
pass = nass ? rank_ok && yield_ok : nil
record("V3",
       question: "Does the crop evidence point at the crops that thrive here?",
       truth: "CDL crops grown at the pin 2008-2025; NASS Story County (and Iowa) yields",
       criterion: "Corn and soybean ranked above wheat and sunflower; GAEZ attainable yield within +-30% of NASS (2001-2010) for both",
       verdict: verdict(pass),
       summary: "GAEZ #{distinguishes ? 'separates' : 'does not separate'} the crops (all #{gaez_rows.values.first[:suit_high]&.round} at high input); " \
                "water model ranks #{top_water.map { |k| GAEZ_NAME[k] }.join(' and ')} first; " \
                "attainable vs NASS: #{checks.map { |k, c| "#{GAEZ_NAME[k]} #{c[:diff_pct]}%" }.join(', ').then { |s| s.empty? ? 'needs NASS' : s }}",
       details: { grown: grown, gaez: gaez_rows, gaez_other: others, water_mean_factor: water, gaez_vs_nass: checks })
