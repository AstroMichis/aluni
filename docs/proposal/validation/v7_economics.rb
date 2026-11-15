# frozen_string_literal: true

# V7 · Would choosing the crop by expected margin have paid? Could the farm plant on time?
#
# Part A, decisions (2008-2025, the CDL years). Each spring a policy picks corn or soybean:
#   farmer       what the CDL shows was planted (strict alternation)
#   aluni        the margin rule the proposal's Gate 3 describes, using only what was known before planting:
#                yield = Story County NASS trend fitted on earlier years x rotation factor;
#                price = NASS Iowa price received, January-March of the planting year;
#                cost  = the worked example's per-ha costs and N rates (placeholders, constant)
#   corn_always  continuous corn
#   foresight    the best sequence with hindsight (dynamic programming): the ceiling no rule can beat
# Realised margin uses the year's actual NASS county yield and the October-December price.
# Rotation factors (corn after corn, soybean after soybean) are placeholders until V4 measures them.
#
# Part B, operations (2001-2025): NASS "days suitable for fieldwork" (Iowa, weekly) between 15 April and
# 20 May, times a planter's field capacity (ASABE D497: C = speed x width x efficiency / 10), gives the
# hectares a farm could plant in the window each year; NASS planting progress gives the real 50% date.
#
# Pre-registered criterion: PASS when the aluni rule's realised margin over 2008-2025 is at least the
# farmer's (no worse than strict alternation). Part B is reported, not scored.
#
# Run: mise exec -- ruby docs/proposal/validation/v7_economics.rb

require_relative "lib"
include Hindcast

need!("nass/yield_county.json", "nass/price_received.json", "cdl.json")
BU_T = { CORN => 39.368, SOY => 36.744 }.freeze # bushels per tonne
BU_AC_TO_T_HA = { CORN => 0.06277, SOY => 0.06725 }.freeze
PLACEHOLDER = {
  "cost" => { CORN => 1040.0, SOY => 815.0 },               # $/ha excluding land and N (worked example)
  "n_rate" => { [ CORN, SOY ] => 150.0, [ CORN, CORN ] => 200.0 }, # kg N/ha by [crop, previous]
  "n_price" => 1.0,                                           # $/kg N
  "rotation" => { [ CORN, CORN ] => 0.90, [ SOY, SOY ] => 0.95 }, # yield factor for a repeat (to be replaced by V4)
  "planter_kmh" => 8.0, "planter_m" => 9.1, "planter_eff" => 0.65, "hours_per_day" => 10.0, "farm_ha" => 400.0
}.freeze

rows = JSON.parse(File.read(path("nass/yield_county.json")))
desc = { CORN => "CORN, GRAIN - YIELD, MEASURED IN BU / ACRE", SOY => "SOYBEANS - YIELD, MEASURED IN BU / ACRE" }
yields = desc.to_h do |k, d|
  [ k, rows.select { |r| r["short_desc"] == d && r["reference_period_desc"] == "YEAR" }
          .filter_map { |r| (v = Float(r["Value"].to_s.delete(","), exception: false)) && [ r["year"].to_i, v * BU_AC_TO_T_HA[k] ] }.to_h ]
end
prices_raw = JSON.parse(File.read(path("nass/price_received.json")))
pdesc = { CORN => "CORN, GRAIN - PRICE RECEIVED, MEASURED IN $ / BU", SOY => "SOYBEANS - PRICE RECEIVED, MEASURED IN $ / BU" }
MONTHS = %w[JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC].freeze
price = pdesc.to_h do |k, d|
  [ k, prices_raw.select { |r| r["short_desc"] == d && MONTHS.include?(r["reference_period_desc"]) }
                .filter_map { |r| (v = Float(r["Value"].to_s.delete(","), exception: false)) && [ [ r["year"].to_i, MONTHS.index(r["reference_period_desc"]) + 1 ], v * BU_T[k] ] }.to_h ]
end
spring = ->(k, y) { v = (1..3).filter_map { |m| price[k][[ y, m ]] }; v.empty? ? nil : mean(v) }
harvest = ->(k, y) { v = (10..12).filter_map { |m| price[k][[ y, m ]] }; v.empty? ? nil : mean(v) }

cdl = JSON.parse(File.read(path("cdl.json"))).transform_keys(&:to_i).transform_values { |c| c == "Corn" ? CORN : SOY }
YEARS = (2008..2025).select { |y| yields.values.all? { |h| h[y] } && [ CORN, SOY ].all? { |k| spring.(k, y) && harvest.(k, y) } }
raise Blocked, "NASS yields or prices missing for the decision years" if YEARS.size < 10

# Corn after corn: the V4 measurement (Zhao 2022, Ames-like climate, farm N rates) when V4 has run.
v4 = File.exist?(OUT) ? JSON.parse(File.read(OUT)).dig("V4", "details", "effects", "Ames-like, maize N >= 120 kg/ha") : nil
ROTATION = PLACEHOLDER["rotation"].merge(v4 ? { [ CORN, CORN ] => v4["corn_after_corn_factor"] } : {})
puts "Corn after corn = #{ROTATION[[ CORN, CORN ]]} x rotated corn (#{v4 ? "V4, Zhao 2022" : "placeholder"}); soybean after soybean #{ROTATION[[ SOY, SOY ]]} (placeholder)"
rot = ->(c, prev) { ROTATION.fetch([ c, prev ], 1.0) }
cost = ->(c, prev) { PLACEHOLDER["cost"][c] + (c == CORN ? PLACEHOLDER["n_rate"].fetch([ CORN, prev ], 150.0) * PLACEHOLDER["n_price"] : 0) }
realised = ->(c, prev, y) { (yields[c][y] * rot.(c, prev) * harvest.(c, y)) - cost.(c, prev) }
expected = lambda do |c, prev, y|
  past = yields[c].select { |yr, _| yr < y && yr >= y - 15 }
  a, b = linear_fit(past.keys, past.values)
  ((a + (b * y)) * rot.(c, prev) * spring.(c, y)) - cost.(c, prev)
end

run = lambda do |choose|
  prev = cdl[YEARS.first - 1]
  YEARS.map do |y|
    c = choose.(y, prev)
    m = realised.(c, prev, y)
    prev = c
    { year: y, crop: c, margin: m.round }
  end
end
policies = {
  "farmer" => run.(->(y, _) { cdl[y] }),
  "aluni" => run.(->(y, prev) { [ CORN, SOY ].max_by { |c| expected.(c, prev, y) } }),
  "corn_always" => run.(->(_, _) { CORN })
}
# Foresight: best path by dynamic programming over (year, crop).
best = { CORN => [ 0, [] ], SOY => [ 0, [] ] }
first_prev = cdl[YEARS.first - 1]
YEARS.each_with_index do |y, i|
  best = [ CORN, SOY ].to_h do |c|
    options = i.zero? ? [ [ first_prev, [ 0, [] ] ] ] : best.to_a
    prev, (score, path) = options.max_by { |p, (s, _)| s + realised.(c, p, y) }
    [ c, [ score + realised.(c, prev, y), path + [ { year: y, crop: c, margin: realised.(c, prev, y).round } ] ] ]
  end
end
policies["foresight"] = best.values.max_by(&:first).last

heading "Part A: realised margin, $/ha, #{YEARS.first}-#{YEARS.last} (placeholder costs, NASS yields and prices)"
totals = policies.transform_values { |p| p.sum { |r| r[:margin] } }
policies.each do |name, p|
  corn = p.count { |r| r[:crop] == CORN }
  puts "#{name.ljust(12)} total $#{totals[name]} (mean $#{(totals[name] / p.size.to_f).round}/ha/yr); corn #{corn} of #{p.size} years"
end
diff_years = policies["aluni"].zip(policies["farmer"]).select { |a, f| a[:crop] != f[:crop] }.map { |a, _| "#{a[:year]} #{a[:crop] == CORN ? 'corn' : 'soy'}" }
puts "The margin rule planted differently from the farmer in: #{diff_years.empty? ? 'no year' : diff_years.join(', ')}"
capture = totals["foresight"] == totals["farmer"] ? nil : (100.0 * (totals["aluni"] - totals["farmer"]) / (totals["foresight"] - totals["farmer"])).round
puts "Share of the hindsight gain over the farmer that the rule captured: #{capture || 'n/a'}%"

heading "Part B: could a #{PLACEHOLDER['farm_ha'].round} ha farm plant corn and soybean between 15 April and 20 May?"
capacity = PLACEHOLDER["planter_kmh"] * PLACEHOLDER["planter_m"] * PLACEHOLDER["planter_eff"] / 10 # ha/h
ops = {}
if File.exist?(path("nass/days_suitable.json"))
  suitable = JSON.parse(File.read(path("nass/days_suitable.json"))).select { |r| r["short_desc"].to_s.include?("DAYS SUITABLE") && r["agg_level_desc"] == "STATE" }
  progress = File.exist?(path("nass/progress.json")) ? JSON.parse(File.read(path("nass/progress.json"))) : []
  (2001..2025).each do |y|
    weeks = suitable.select { |r| r["year"].to_i == y && r["week_ending"].to_s[0, 10].then { |d| !d.empty? && (Date.new(y, 4, 15)..Date.new(y, 5, 26)).cover?(Date.parse(d)) } }
    days = weeks.sum { |r| Float(r["Value"].to_s, exception: false).to_f }
    next if weeks.empty?

    ha = days * PLACEHOLDER["hours_per_day"] * capacity
    half = progress.select { |r| r["year"].to_i == y && r["commodity_desc"] == "CORN" && Float(r["Value"].to_s, exception: false).to_f >= 50 }
                   .filter_map { |r| r["week_ending"].to_s[0, 10].then { |d| d.empty? ? nil : Date.parse(d) } }.min
    ops[y] = { days: days.round(1), plantable_ha: ha.round, enough: ha >= PLACEHOLDER["farm_ha"], corn_50pct_planted: half }
    puts "#{y}: #{days.round(1)} suitable days -> #{ha.round} ha with one planter (#{ops[y][:enough] ? 'enough' : 'SHORT'}); Iowa corn 50% planted by #{half || '-'}"
  end
  short = ops.select { |_, o| !o[:enough] }.keys
  puts "Planter capacity #{capacity.round(2)} ha/h. Short of time in #{short.size} of #{ops.size} springs: #{short.join(', ')}"
else
  puts "BLOCKED: nass/days_suitable.json missing"
end

pass = totals["aluni"] >= totals["farmer"]
record("V7",
       question: "Would choosing by expected margin have paid, and could the farm plant on time?",
       truth: "NASS Story County yields, NASS Iowa prices received and days suitable for fieldwork; placeholder costs",
       criterion: "The margin rule's realised margin 2008-2025 is at least the farmer's (strict alternation)",
       verdict: verdict(pass),
       summary: "margin rule $#{totals['aluni']} vs farmer $#{totals['farmer']} vs continuous corn $#{totals['corn_always']} vs hindsight $#{totals['foresight']} per ha over #{YEARS.size} years; " \
                "differs from the farmer in #{diff_years.size} years; short of planting days in #{ops.count { |_, o| !o[:enough] }} of #{ops.size} springs",
       details: { years: YEARS, totals: totals, policies: policies, capture_pct: capture, operations: ops, placeholders: PLACEHOLDER, corn_after_corn: ROTATION[[ CORN, CORN ]] })
