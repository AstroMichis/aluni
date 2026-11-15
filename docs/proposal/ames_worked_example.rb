# frozen_string_literal: true

# Worked example for the integrated proposal: Aluni's formulas run by hand on one real
# field, farm_data_42.0_-93.75.csv (Ames, Iowa; NASA POWER daily 2025, USGS 3DEP, SSURGO,
# CDL 2020-2025). Each section names the service it mirrors, so every number in the
# proposal can be traced to a formula, a data row and a line of the app:
#
#   1 data      the CSV, with checks on completeness and NASA POWER fill values
#   2 weather   Weather::Et0 (FAO-56 Penman-Monteith), Weather::Season (frost, heavy rain, dry spell)
#   3 water     Crops::WaterNeed (FAO-56 Kc curve, FAO/CROPWAT effective rain), crops read from config/crops/agronomy.yml
#   4 compare   Rotations::Comparator (candidates, the six scores it can compute here, weights, benefits, risks)
#   5 timeline  Rotations::Timeline (three seasons, bare months, exposure, cover windows)
#   6 pests     pest_weather_rules.md: what daily NASA POWER can compute (tar spot, fall armyworm) and what needs hourly data
#   7 nitrogen  nutrient_removal.md: N applied, fixed and removed per strategy, on water-limited yields (FAO-56 soil water, FAO-33 Ky)
#   8 margin    the market sources (NASS, AMS, ERS): $/ha per strategy, price sensitivity, against the agronomic ranking
#   9 device    DEVICES.md: which gap each sensor closes, the wind sensitivity of ET0, the validation metric per sensor
#  10 landing   the sample figures in app/helpers/landing_helper.rb, recomputed
#  11 checks    a pass/fail list; the script exits 1 if any fails
#
# Sections 7 and 8 rest on inputs that are not in the CSV. Each is tagged placeholder, published or
# cited, and real values go in docs/proposal/ames_inputs.json (see "inputs that are not in the CSV").
#
# Run: mise exec -- ruby docs/proposal/ames_worked_example.rb [path/to/farm_data.csv]
# Plain Ruby (csv, date, json, yaml), no Rails. Writes ames_worked_example_out.json next to itself.
#
# Differences from the app, on purpose: the app reads 20-30 year NASA POWER normals and
# 20 years of GPM IMERG; this file has one year (2025) of daily NASA POWER, so ET0 is
# computed per day and "stormy" means a heavy day in 2025. What the file lacks is listed
# under "gaps" in the output, never filled in silently.

require "csv"
require "date"
require "json"
require "yaml"

ROOT = File.expand_path("../..", __dir__)
CSV_PATH = ARGV[0] || File.join(ROOT, "farm_data_42.0_-93.75.csv")
OUT_PATH = File.expand_path("ames_worked_example_out.json", __dir__)
AGRONOMY = YAML.safe_load_file(File.join(ROOT, "config/crops/agronomy.yml"))

CHECKS = []
GAPS = []
def check(label, ok, detail = nil) = CHECKS << { check: label, ok: ok ? true : false, detail: detail }
def gap(key, why) = GAPS << { gap: key, why: why }
def slug(name) = name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").delete_suffix("-")
def crop_key(name) = AGRONOMY.key?(slug(name)) ? slug(name) : AGRONOMY.find { |_, b| Array(b["aliases"]).include?(slug(name)) }&.first
def short(key) = AGRONOMY.dig(key, "aliases").first
def heading(text) = puts("\n== #{text} ==")

# ---------------------------------------------------------------- 1 data
POWER_VARS = %w[air_temp_max air_temp_min air_temp_mean relative_humidity solar_radiation precipitation].freeze
d = Hash.new { |h, k| h[k] = {} }
units = {}
facts = {}
cdl = {}
lat = lon = nil
CSV.foreach(CSV_PATH, headers: true) do |r|
  lat ||= Float(r["lat"])
  lon ||= Float(r["lon"])
  case r["source"]
  when "NASA POWER"
    d[Date.parse(r["date"])][r["variable"]] = Float(r["value"])
    units[r["variable"]] = r["unit"]
  when "USDA CDL" then cdl[Integer(r["date"])] = r["value"]
  else facts[r["variable"]] = r["value"]
  end
end
days = d.keys.sort
months = days.map(&:month).uniq
missing = days.flat_map { |day| (POWER_VARS - d[day].keys).map { |v| "#{day} #{v}" } }
fills = days.flat_map { |day| d[day].select { |_, v| v <= -999 }.map { |v, _| "#{day} #{v}" } }
check("NASA POWER days are contiguous", days.each_cons(2).all? { |a, b| b == a + 1 }, "#{days.first}..#{days.last}, #{days.size} days")
check("every day has the six variables ET0 needs", missing.empty?, missing.first(5).join(", "))
check("no NASA POWER fill values (-999)", fills.empty?, fills.first(5).join(", "))
check("solar radiation is in MJ/m2/day (FAO-56 units)", units["solar_radiation"] == "MJ/m2/day", units["solar_radiation"])
check("precipitation is in mm/day", units["precipitation"] == "mm/day", units["precipitation"])

ELEV = Float(facts.fetch("elevation"))        # USGS 3DEP
SLOPE_3DEP = Float(facts.fetch("slope"))      # USGS 3DEP (derived): what Comparator#erosion reads first
SLOPE_SSURGO = Float(facts.fetch("mapped_slope")) # SSURGO map unit representative slope, for the sensitivity run
history = cdl.sort.last(2).map { |year, name| [ year, crop_key(name) ] } # Comparator#pest_break reads the last two seasons
check("CDL history maps to catalog crops", history.all? { |_, k| k }, cdl.inspect)

# Wind: the CSV has no WS2M. When docs/proposal/validation/fetch.rb has run, the day's NASA POWER WS2M at the
# pin is used (the app's own source); otherwise the FAO-56 default of 2 m/s (FAO-56 Sec. 3).
U2 = 2.0
power_file = File.expand_path("validation/data/power_daily.json", __dir__)
WIND = if File.exist?(power_file)
         JSON.parse(File.read(power_file)).dig("properties", "parameter", "WS2M").to_h
             .filter_map { |k, v| [ Date.strptime(k, "%Y%m%d"), v ] if v && v > -999 }.to_h
else
         {}
end
if WIND.empty?
  gap("wind", "CSV has no NASA POWER WS2M; ET0 uses the FAO-56 default 2 m/s (run validation/fetch.rb for the measured wind)")
else
  check("measured NASA POWER wind covers every day of the record", days.all? { |x| WIND[x] }, "WS2M from validation/data/power_daily.json")
end
gap("normals", "one year (2025) of daily data stands in for the 30-year NASA POWER normals the app uses")
gap("nov_dec", "data ends #{days.last}; November and December are unknown months in the timeline") if days.last.month < 12

puts "Field #{lat}, #{lon}  elevation #{ELEV.round} m  slope #{SLOPE_3DEP}% (3DEP), #{SLOPE_SSURGO}% (SSURGO map unit)"
puts "Soil: #{facts['soil_map_unit']}; OM #{facts['organic_matter']}%, sand #{facts['sand']}%, clay #{facts['clay']}%, AWC #{facts['available_water_capacity']}, group #{facts['hydrologic_soil_group']}"
puts "CDL: #{cdl.sort.map { |y, c| "#{y} #{c}" }.join(', ')}"

# ---------------------------------------------------------------- 2 weather (Weather::Et0, Weather::Season)
SIGMA = 4.903e-9
GSC = 0.0820
ALBEDO = 0.23
P = 101.3 * (((293 - (0.0065 * ELEV)) / 293)**5.26)
GAMMA = 0.000665 * P

# FAO-56 Eq. 21, same as Weather::Et0.extraterrestrial
def ra(lat, doy)
  phi = lat * Math::PI / 180
  dr = 1 + (0.033 * Math.cos(2 * Math::PI * doy / 365))
  dec = 0.409 * Math.sin((2 * Math::PI * doy / 365) - 1.39)
  ws = Math.acos((-Math.tan(phi) * Math.tan(dec)).clamp(-1, 1))
  (24 * 60 / Math::PI) * GSC * dr * ((ws * Math.sin(phi) * Math.sin(dec)) + (Math.cos(phi) * Math.cos(dec) * Math.sin(ws)))
end

def e0(t) = 0.6108 * Math.exp(17.27 * t / (t + 237.3))

# Daily FAO-56 Eq. 6. With Tmax and Tmin per day it uses Eq. 12 (es) and Eq. 39 (Rnl) in full,
# where the app's monthly version has only the mean temperature.
et0_series = ->(u2) { days.to_h { |day| [ day, et0_day(d[day], day, lat, u2) ] } }
def et0_day(v, day, lat, u2)
  u2 = WIND.fetch(day, U2) if u2.nil?
  tmax, tmin, rh, rs = v.values_at("air_temp_max", "air_temp_min", "relative_humidity", "solar_radiation")
  t = (tmax + tmin) / 2
  es = (e0(tmax) + e0(tmin)) / 2
  ea = es * rh / 100 # Eq. 19, RH mean
  delta = 4098 * e0(t) / ((t + 237.3)**2)
  rso = (0.75 + (2e-5 * ELEV)) * ra(lat, day.yday)
  rnl = SIGMA * (((tmax + 273.16)**4 + (tmin + 273.16)**4) / 2) * (0.34 - (0.14 * Math.sqrt(ea))) * ((1.35 * [ rs / rso, 1.0 ].min) - 0.35)
  rn = ((1 - ALBEDO) * rs) - rnl
  [ ((0.408 * delta * rn) + (GAMMA * (900 / (t + 273)) * u2 * (es - ea))) / (delta + (GAMMA * (1 + (0.34 * u2)))), 0 ].max
end
et0 = et0_series.(nil) # the day's measured wind, or U2 where there is none
rain =days.to_h { |x| [ x, d[x]["precipitation"] ] }
check("daily ET0 within 0-12 mm (FAO-56 plausible range)", et0.values.all? { |x| x.between?(0, 12) }, "max #{et0.values.max.round(2)}")

heading "Weather::Et0 + Weather::Season, 2025 by month"
puts "MONTH  ET0mm  RAINmm  frost  heavy>=25  ext>=50  maxday  Tmean  Tmax"
monthly = months.to_h do |m|
  sel = days.select { |x| x.month == m }
  row = { et0: sel.sum { |x| et0[x] }.round(1), rain: sel.sum { |x| rain[x] }.round(1),
          frost: sel.count { |x| d[x]["air_temp_min"] <= 0 }, heavy: sel.count { |x| rain[x] >= 25 },
          ext: sel.count { |x| rain[x] >= 50 }, max_day: sel.map { |x| rain[x] }.max,
          t_mean: (sel.sum { |x| d[x]["air_temp_mean"] } / sel.size).round(1), t_max: sel.map { |x| d[x]["air_temp_max"] }.max, n: sel.size }
  printf("%3d   %6.1f  %6.1f   %3d     %3d      %3d   %5.1f   %5.1f  %5.1f\n", m, *row.values_at(:et0, :rain, :frost, :heavy, :ext, :max_day, :t_mean, :t_max))
  [ m, row ]
end
gdd = ->(sel) { sel.sum { |x| [ ((d[x]["air_temp_max"].clamp(10, 30) + d[x]["air_temp_min"].clamp(10, 30)) / 2) - 10, 0 ].max }.round }
dry = days.chunk_while { |a, b| rain[a] < 1 && rain[b] < 1 }.select { |r| rain[r.first] < 1 }.max_by(&:size)
spring = days.select { |x| x.month < 7 && d[x]["air_temp_min"] <= 0 }.last
fall = days.find { |x| x.month >= 7 && d[x]["air_temp_min"] <= 0 }
season = {
  et0_mm: et0.values.sum.round, rain_mm: rain.values.sum.round,
  frost_days: monthly.values.sum { |r| r[:frost] }, gdd_86_50_may_sep: gdd.(days.select { |x| (5..9).cover?(x.month) }),
  gdd_86_50_all: gdd.(days), gdd_simple_all: days.sum { |x| [ d[x]["air_temp_mean"] - 10, 0 ].max }.round, longest_dry_spell: { days: dry.size, from: dry.first, to: dry.last },
  last_spring_frost: spring, first_fall_frost: fall || "none through #{days.last}"
}
puts "#{days.first}..#{days.last}: ET0 #{season[:et0_mm]} mm, rain #{season[:rain_mm]} mm, frost days #{season[:frost_days]}"
puts "GDD base 10: 86/50 method May-Sep #{season[:gdd_86_50_may_sep]}, whole record #{season[:gdd_86_50_all]}; simple (T2M - 10) whole record #{season[:gdd_simple_all]}"
puts "Longest dry spell (<1 mm/day): #{dry.size} days, #{dry.first}..#{dry.last}"
puts "Last spring frost #{spring}; first fall frost #{season[:first_fall_frost]}"

# ---------------------------------------------------------------- 3 water (Crops::WaterNeed)
# The CROPWAT formula is for a month's rain: a partial month is scaled up to a full month and back, as the app does.
def eff(mm) = mm > 75 ? (0.8 * mm) - 25 : [ (0.6 * mm) - 10, 0 ].max

def kc(day, (k_ini, k_mid, k_end), (ini, dev, mid, late))
  return k_ini if day < ini
  return k_ini + ((k_mid - k_ini) * (day - ini) / dev.to_f) if day < ini + dev
  return k_mid if day < ini + dev + mid

  k_mid + ((k_end - k_mid) * (day - ini - dev - mid) / late.to_f)
end

water_need = lambda do |key, planting_month = nil, series: et0|
  fao = AGRONOMY.dig(key, "fao56") or next nil
  start = Date.new(days.first.year, planting_month || fao["planting_month"], 1)
  last = start + fao["stages"].sum - 1
  raise "#{key}: season #{start}..#{last} runs past the data (#{days.last})" if last > days.last

  crop = Hash.new(0.0)
  rn = Hash.new(0.0)
  cnt = Hash.new(0)
  fao["stages"].sum.times do |i|
    day = start + i
    crop[day.month] += kc(i, fao["kc"], fao["stages"]) * series[day]
    rn[day.month] += rain[day]
    cnt[day.month] += 1
  end
  e = rn.to_h { |m, mm| dim = Date.new(start.year, m, -1).day; [ m, eff(mm * dim / cnt[m]) * cnt[m] / dim ] }
  deficit = crop.sum { |m, mm| [ mm - e[m], 0 ].max }
  { key: key, from: start, to: last, days: fao["stages"].sum, crop_mm: crop.values.sum.round, rain_mm: rn.values.sum.round,
    effective_mm: e.values.sum.round, deficit_mm: deficit.round,
    share_app: (e.values.sum / crop.values.sum).round(3),       # what Comparator#water scores
    share_met: ((crop.values.sum - deficit) / crop.values.sum).round(3), # month by month, surplus months do not pay for dry ones
    monthly: crop.keys.to_h { |m| [ m, { etc: crop[m].round(1), effective: e[m].round(1) } ] } }
end

heading "Crops::WaterNeed on 2025 daily data (FAO-56 planting months from config/crops/agronomy.yml)"
CROPS = %w[corn soybean wheat sunflower].map { |n| crop_key(n) }
need = CROPS.to_h { |k| [ k, water_need.(k) ] }
need.each_value do |n|
  printf("%-10s %s..%s  ETc %4d  rain %4d  effective %4d  deficit %4d  covered %3.0f%% (app ratio) %3.0f%% (month by month)\n",
         short(n[:key]), n[:from], n[:to], n[:crop_mm], n[:rain_mm], n[:effective_mm], n[:deficit_mm], 100 * n[:share_app], 100 * n[:share_met])
end
check("each need: effective rain never above total rain", need.values.all? { |n| n[:effective_mm] <= n[:rain_mm] })
check("Kc curve reaches Kc end on the last day", CROPS.all? { |k| f = AGRONOMY.dig(k, "fao56"); (kc(f["stages"].sum, f["kc"], f["stages"]) - f["kc"][2]).abs < 1e-9 })

# ---------------------------------------------------------------- 4 compare (Rotations::Comparator)
# The profile is not in the CSV. These answers are borrowed from config/demo_farms.yml (nebraska)
# and must be replaced by the Ames farmer's own onboarding answers.
PROFILE = { goals: %w[rotation soil_health], equipment: %w[tractor planter sprayer harvester], irrigation: "rainfed" }.freeze
gap("profile", "goals, equipment and irrigation are assumed (demo_farms.yml nebraska), not the Ames farmer's answers")
gap("crop_fit", "FAO GAEZ suitability is not in the CSV: crop_fit is left out of the total, as the app does when GAEZ has not answered")
gap("perennial", "the alfalfa strategy needs GAEZ to call alfalfa suitable (Comparator#suitable?), so it is not offered here")
gap("imerg", "storm penalty and stormy months use 2025 NASA POWER rain, not 20 years of GPM IMERG")

HORIZON = 3
GOAL_WEIGHTS = { "crop_fit" => %w[crop_fit yield], "pest_break" => %w[rotation], "soil_health" => %w[soil_health],
                 "nitrogen" => %w[soil_health], "water" => %w[water_saving], "erosion" => %w[soil_health], "workload" => %w[labour] }.freeze
ROW_CROPS = %w[zea-mays sorghum-bicolor glycine-max phaseolus-vulgaris solanum-tuberosum helianthus-annuus gossypium-hirsutum].freeze
LEGUMES = [ "Soybean", "Phaseolus bean", "Chickpea", "Dry pea", "Groundnut", "Cowpea" ].freeze
SMALL_GRAINS = %w[Wheat Oat Barley Rye].freeze
FALLBACK_OTHERS = %w[Maize Sorghum Sunflower].freeze
family = ->(k) { AGRONOMY.dig(k, "family") }
legume = ->(k) { family.(k) == "fabaceae" }
best_of = ->(names, exclude: []) { names.filter_map { |g| AGRONOMY.find { |_, b| b["gaez"] == g }&.first }.find { |k| !exclude.include?(family.(k)) } }

# Comparator#candidates and #continue, with GAEZ silent (its fallback order)
before, now = history.map(&:last)
current = before.nil? || before == now ? [ now ] * HORIZON : [ before, now, before ]
families = current.map(&family).uniq
has_legume = current.any?(&legume)
leg = best_of.(LEGUMES)
grain = best_of.(SMALL_GRAINS)
other = best_of.(FALLBACK_OTHERS, exclude: families)
strategies = { "current" => current }
strategies["legume"] = [ leg, now, leg ] if leg && !has_legume
strategies["small_grain"] = [ grain, (has_legume ? current.find(&legume) : leg) || now, now ] if grain
strategies["other_family"] = [ other, now, other ] if other
strategies = strategies.uniq { |_, c| c }.to_h
strategies.each_value { |crops| crops.each { |k| need[k] ||= water_need.(k) } }

# Weather::RainExtremes#stormy_field?: 50 mm days at least once a year
stormy_field = monthly.values.sum { |m| m[:ext] } >= 1
pest_break = lambda do |crops|
  seq = history.map(&:last) + crops
  same = seq.each_cons(2).count { |a, b| family.(a) && family.(a) == family.(b) }
  mono = seq.chunk_while { |a, b| a == b }.count { |r| r.size >= 3 }
  [ 100 - (same * 25) - (mono * 30), 0 ].max
end
score = lambda do |crops, slope: SLOPE_3DEP, profile: PROFILE|
  harvester = profile[:equipment].include?("harvester")
  grains = crops.any? { |c| SMALL_GRAINS.include?(AGRONOMY.dig(c, "gaez")) }
  shares = crops.map { |c| need[c][:share_app] }
  {
    "pest_break" => pest_break.(crops),
    "soil_health" => [ 25 + (crops.count(&legume) * 20) + (crops.map(&family).uniq.size * 10) + (crops.count { |c| !ROW_CROPS.include?(c) } * 10), 100 ].min,
    "nitrogen" => (100.0 * crops.count(&legume) / crops.size).round,
    "water" => (profile[:irrigation] == "rainfed" ? 100 * shares.sum / shares.size : 60 + (40 * shares.sum / shares.size)).clamp(0, 100).round,
    "erosion" => [ 100 - (crops.count { |c| ROW_CROPS.include?(c) } * ((slope >= 5 ? 25 : 8) + (stormy_field ? 7 : 0))), 0 ].max,
    "workload" => (100 - ((crops.uniq.size - 1) * 15) - (grains && !harvester ? 20 : 0)).clamp(0, 100)
  }
end
weights_for = ->(goals) { (GOAL_WEIGHTS.keys - [ "crop_fit" ]).to_h { |c| [ c, (GOAL_WEIGHTS[c] & goals).any? ? 3 : 1 ] } }
total = ->(sc, w) { (sc.sum { |c, v| v * w[c] } / sc.keys.sum { |c| w[c] }.to_f).round }
risks = lambda do |crops, sc|
  list = []
  list << "dry" if PROFILE[:irrigation] == "rainfed" && crops.uniq.any? { |c| need[c][:rain_mm] < need[c][:crop_mm] * 0.5 }
  list << "harvester" if crops.any? { |c| SMALL_GRAINS.include?(AGRONOMY.dig(c, "gaez")) } && !PROFILE[:equipment].include?("harvester")
  list << "same_family" if sc["pest_break"] < 75
  list << "heavy_rain" if stormy_field && crops.any? { |c| ROW_CROPS.include?(c) }
  list
end

heading "Rotations::Comparator (history #{history.map { |y, k| "#{y} #{short(k)}" }.join(', ')}; profile assumed)"
weights = weights_for.(PROFILE[:goals])
puts "weights: #{weights}"
compare = strategies.to_h do |key, crops|
  sc = score.(crops)
  [ key, { crops: crops.map { |c| short(c) }, scores: sc, total: total.(sc, weights), risks: risks.(crops, sc) } ]
end
compare.each_value { |s| s[:benefits] = s[:scores].select { |c, v| v - compare["current"][:scores][c] >= 10 }.keys }
compare["current"][:benefits] = []
compare.each do |key, s|
  puts "#{key.ljust(13)} #{s[:crops].join('>').ljust(26)} #{s[:scores].map { |c, v| "#{c}=#{v}" }.join(' ')}  TOTAL=#{s[:total]}"
  puts "#{' ' * 14}benefits vs current: #{s[:benefits].empty? ? '-' : s[:benefits].join(', ')}; risks: #{s[:risks].empty? ? '-' : s[:risks].join(', ')}"
end

heading "Sensitivity: the same strategies when one input changes"
variants = {
  "baseline (3DEP slope #{SLOPE_3DEP}%)" => {},
  "SSURGO mapped slope #{SLOPE_SSURGO}%" => { slope: SLOPE_SSURGO },
  "no harvester" => { profile: PROFILE.merge(equipment: %w[tractor planter sprayer]) },
  "no goals (all weights 1)" => { profile: PROFILE.merge(goals: []) }
}
sensitivity = variants.to_h do |label, opts|
  w = weights_for.((opts[:profile] || PROFILE)[:goals])
  totals = strategies.to_h { |key, crops| [ key, total.(score.(crops, **opts), w) ] }
  puts "#{label.ljust(32)} #{totals.map { |k, v| "#{k}=#{v}" }.join('  ')}  winner: #{totals.max_by(&:last).first}"
  [ label, totals ]
end

# ---------------------------------------------------------------- 5 timeline (Rotations::Timeline)
risk_strip = (1..12).to_h do |m|
  r = monthly[m]
  next [ m, nil ] unless r # no data: unknown month

  [ m, [ ("storm" if r[:heavy] >= 1), ("dry" if r[:rain] < 0.5 * r[:et0]), ("frost" if r[:frost] >= 2), ("heat" if r[:t_max] >= 35) ].compact ]
end
heading "Rotations::Timeline, 2025 weather repeated for three seasons (#{(risk_strip.compact.keys.minmax).join('-')} known)"
puts "month risks: #{risk_strip.compact}"
# Timeline#season_of: FAO-56 planting month and ceil(days / 30.4) months. The current crop uses the
# farmer's record when there is one; CDL gives no planting or harvest month, so FAO-56 it is.
season_of = ->(k, record = nil) { record || [ AGRONOMY.dig(k, "fao56", "planting_month"), (AGRONOMY.dig(k, "fao56", "stages").sum / 30.4).ceil ] }
timeline = lambda do |crops, record: {}|
  states = Array.new(12 * HORIZON, "bare")
  crops.each_with_index do |c, s|
    plant, len = season_of.(c, record[c])
    (0...len).each { |i| idx = (s * 12) + plant - 1 + i; states[idx] = short(c) if idx < states.size }
  end
  line = states.each_with_index.map do |st, i|
    m = (i % 12) + 1
    risks = risk_strip[m]
    { index: i, month: m, state: risks.nil? && st == "bare" ? "unknown" : st, risks: risks || [] }
  end
  vulnerable = line.select { |x| x[:state] == "bare" && (x[:risks] & %w[storm dry frost]).any? }
  windows = line.chunk_while { |a, b| a[:state] == "bare" && b[:state] == "bare" }.select { |r| r.first[:state] == "bare" && r.size >= 2 }
  protected = windows.sum { |w| w.drop(1).count { |x| (x[:risks] & %w[storm dry frost]).any? } }
  { strip: line.map { |x| x[:state] == "bare" ? "." : x[:state] == "unknown" ? "?" : x[:state][0].upcase }.each_slice(12).map(&:join).join(" | "),
    bare: line.count { |x| x[:state] == "bare" }, vulnerable: vulnerable.size, exposed_with_cover: vulnerable.size - protected,
    vulnerable_months: vulnerable.map { |x| "#{2026 + (x[:index] / 12)}-#{format('%02d', x[:month])}" } }
end
CORN_RECORD = { crop_key("corn") => [ 4, 7 ] }.freeze # what a farmer who answers "plant April, harvest October" gives
lines = {}
strategies.each do |key, crops|
  [ [ "FAO-56", {} ], [ "corn Apr-Oct record", CORN_RECORD ] ].each do |label, rec|
    next if label != "FAO-56" && !crops.include?(crop_key("corn"))

    t = timeline.(crops, record: rec)
    lines["#{key} (#{label})"] = t
    puts "#{key.ljust(13)} #{label.ljust(20)} #{t[:strip]}  bare #{t[:bare]}, vulnerable #{t[:vulnerable]}, with cover #{t[:exposed_with_cover]}"
  end
end
puts "(J..D per season: letter = crop, . = bare, ? = no data)"

# ---------------------------------------------------------------- inputs that are not in the CSV
# Every number below is one of three kinds, and the output says which:
#   placeholder  an ILLUSTRATIVE value standing in for a keyed fetch or the farmer's answer; replace it
#   published    a constant from a cited table, not yet captured in docs/data_sources/
#   cited        a value quoted in docs/data_sources/ (cite-only licence noted there)
# Real values go in docs/proposal/ames_inputs.json, e.g. {"price.zea-mays": 171.5}; they override
# these and are reported as "provided". No code change needed.
CORN, SOY, WHEAT, SUN = %w[corn soybean wheat sunflower].map { |n| crop_key(n) }
ISU = "Iowa State Ag Decision Maker crop budgets (A1-20) or USDA ERS commodity costs and returns (CSV, no API; usda_ers.md)"
INPUTS = {
  # Yield potential without water stress, t/ha. Fetch: NASS QuickStats YIELD, county STORY (IA), 5-year mean (nass_quickstats.md, key).
  "yield.#{CORN}" => [ 12.5, "placeholder", "NASS QuickStats CORN, GRAIN - YIELD, Story County IA, BU/ACRE x 0.0628" ],
  "yield.#{SOY}" => [ 4.0, "placeholder", "NASS QuickStats SOYBEANS - YIELD, Story County IA, BU/ACRE x 0.0673" ],
  "yield.#{WHEAT}" => [ 4.5, "placeholder", "NASS QuickStats WHEAT, SPRING - YIELD (Iowa has little wheat: use MN or the farmer's own)" ],
  "yield.#{SUN}" => [ 2.2, "placeholder", "NASS QuickStats SUNFLOWER - YIELD, LB/ACRE x 0.00112 (ND/SD; none in Iowa)" ],
  # Price, $/t. Fetch: AMS report 2850 Iowa Daily Cash Grain Bids (ams_market_news.md, key) or NASS PRICE RECEIVED, IA, monthly.
  "price.#{CORN}" => [ 165.0, "placeholder", "AMS 2850 Iowa cash corn bid, $/bu x 39.37" ],
  "price.#{SOY}" => [ 375.0, "placeholder", "AMS 2850 Iowa cash soybean bid, $/bu x 36.74" ],
  "price.#{WHEAT}" => [ 200.0, "placeholder", "AMS 3046 Minneapolis spring wheat, $/bu x 36.74" ],
  "price.#{SUN}" => [ 450.0, "placeholder", "NASS PRICE RECEIVED SUNFLOWER, $/CWT x 22.05" ],
  # Cost per ha excluding land (the same under every strategy) and nitrogen (priced below).
  "cost.#{CORN}" => [ 1040.0, "placeholder", ISU ],
  "cost.#{SOY}" => [ 815.0, "placeholder", ISU ],
  "cost.#{WHEAT}" => [ 620.0, "placeholder", ISU ],
  "cost.#{SUN}" => [ 690.0, "placeholder", ISU ],
  "n_price" => [ 1.0, "placeholder", "$/kg N: AMS Iowa Production Cost Report or ERS fertilizer prices (not yet documented)" ],
  # Fertilizer N, kg/ha, by previous crop. Fetch: Iowa State MRTN calculator (not yet in data_sources/).
  "n_rate.#{CORN}.after_legume" => [ 150.0, "placeholder", "MRTN, corn following soybean, Iowa" ],
  "n_rate.#{CORN}.after_other" => [ 200.0, "placeholder", "MRTN, corn following corn (used for any non-legume)" ],
  "n_rate.#{SOY}" => [ 0.0, "placeholder", "soybean is not fertilized with N in Iowa" ],
  "n_rate.#{WHEAT}" => [ 90.0, "placeholder", "state extension spring wheat N guide" ],
  "n_rate.#{SUN}" => [ 70.0, "placeholder", "NDSU sunflower N guide" ],
  # N removed in grain, kg N per t. nutrient_removal.md quotes OMAFRA ranges (cite-only); the CC0 Ludemann
  # Tier_1_and_2_crop_coefficients.csv replaces these once it is downloaded (Dryad token).
  "n_removal.#{CORN}" => [ 14.6, "cited", "OMAFRA grain corn 11.5-17.7 kg N/t, midpoint (nutrient_removal.md)" ],
  "n_removal.#{SOY}" => [ 64.5, "cited", "OMAFRA soybean 62.3-66.7 kg N/t, midpoint (nutrient_removal.md)" ],
  "n_removal.#{WHEAT}" => [ 20.0, "cited", "OMAFRA wheat 19.1-20.9 kg N/t, midpoint (nutrient_removal.md)" ],
  "n_removal.#{SUN}" => [ 28.0, "placeholder", "no documented value; Ludemann coefficients" ],
  "fixation_share.#{SOY}" => [ 0.5, "placeholder", "share of soybean N from fixation (literature 0.4-0.7); Ludemann or ISU" ],
  # FAO-33 Table 24 yield response to water, Ky (season). Not yet in data_sources/.
  "ky.#{CORN}" => [ 1.25, "published", "FAO Irrigation and Drainage Paper 33, maize" ],
  "ky.#{SOY}" => [ 0.85, "published", "FAO-33, soybean" ],
  "ky.#{WHEAT}" => [ 1.15, "published", "FAO-33, spring wheat" ],
  "ky.#{SUN}" => [ 0.95, "published", "FAO-33, sunflower" ],
  # FAO-56 Table 22: depletion fraction p and the lower bound of the maximum root depth Zr (m).
  "p.#{CORN}" => [ 0.55, "published", "FAO-56 Table 22, maize grain" ], "zr.#{CORN}" => [ 1.0, "published", "FAO-56 Table 22, maize 1.0-1.7 m" ],
  "p.#{SOY}" => [ 0.50, "published", "FAO-56 Table 22, soybeans" ], "zr.#{SOY}" => [ 0.6, "published", "FAO-56 Table 22, soybeans 0.6-1.3 m" ],
  "p.#{WHEAT}" => [ 0.55, "published", "FAO-56 Table 22, spring wheat" ], "zr.#{WHEAT}" => [ 1.0, "published", "FAO-56 Table 22, spring wheat 1.0-1.5 m" ],
  "p.#{SUN}" => [ 0.45, "published", "FAO-56 Table 22, sunflower" ], "zr.#{SUN}" => [ 0.8, "published", "FAO-56 Table 22, sunflower 0.8-1.5 m" ]
}.to_h { |k, (v, status, source)| [ k, { value: v, status: status, source: source } ] }
inputs_path = File.expand_path("ames_inputs.json", __dir__)
if File.exist?(inputs_path)
  JSON.parse(File.read(inputs_path)).each do |k, v|
    raise "ames_inputs.json: unknown input #{k}" unless INPUTS.key?(k)

    INPUTS[k] = INPUTS[k].merge(value: Float(v), status: "provided")
  end
end
used = {}
input = ->(k) { used[k] = INPUTS.fetch(k); INPUTS.fetch(k)[:value] }

# ---------------------------------------------------------------- 6 pests (pest_weather_rules.md, on the daily data)
# Weather favourable to a pest is not the pest: these say when to scout, not that it is there.
heading "Pests: what the daily NASA POWER data can and cannot say"
mean30 = days.each_with_index.to_h { |day, i| [ day, i >= 29 ? days[(i - 29)..i].sum { |x| d[x]["air_temp_mean"] } / 30 : nil ] }
corn_season = need[CORN][:from]..need[CORN][:to]
tar = corn_season.select { |x| mean30[x]&.between?(18, 23) }
tar_runs = tar.chunk_while { |a, b| b == a + 1 }.map(&:size)
puts "Tar spot (corn; Sci. Reports 2023: 30-day mean T2M 18-23 C most predictive): #{tar.size} of #{corn_season.count} corn-season days favourable, " \
     "first #{tar.first || '-'}, longest run #{tar_runs.max || 0} days"
humid = corn_season.count { |x| d[x]["relative_humidity"] >= 90 }
puts "  RH: #{humid} corn-season days with daily mean RH >= 90%; the rule's RH term is hourly, so this is a proxy only"
faw_window = days.select { |x| (5..10).cover?(x.month) }
faw = { "du Plessis 2020 (12.57 C, 391 DD)" => [ 12.57, 391 ], "Malekera 2022 linear (9.73 C, 490 DD)" => [ 9.73, 490 ] }.to_h do |label, (base, gen)|
  dd = faw_window.sum { |x| [ ((d[x]["air_temp_max"] + d[x]["air_temp_min"]) / 2) - base, 0 ].max }
  puts "Fall armyworm, #{label}: #{dd.round} degree-days May-Oct = #{(dd / gen).round(1)} generations possible after arrival"
  [ label, { dd: dd.round, generations: (dd / gen).round(2) } ]
end
puts "  Fall armyworm does not overwinter where it freezes: the arrival date comes from trap data (fao_data_catalog.md FAMEWS, insect_monitoring_datasets.md)"
HOURLY_RULES = { CORN => [ "gray leaf spot", "northern corn leaf blight" ], SOY => [ "Asian soybean rust" ],
                 WHEAT => [ "stripe rust", "leaf rust", "stem rust", "Fusarium head blight (De Wolf)" ], SUN => [] }.freeze
pests = strategies.to_h do |key, crops|
  daily = crops.include?(CORN) ? [ "tar spot (#{crops.count(CORN)} corn season#{"s" if crops.count(CORN) > 1})", "fall armyworm degree-days" ] : []
  hourly = crops.uniq.flat_map { |c| HOURLY_RULES[c] }
  puts "#{key.ljust(13)} computable now: #{daily.empty? ? '-' : daily.join(', ')}; needs hourly T/RH/leaf wetness: #{hourly.empty? ? '-' : hourly.join(', ')}"
  [ key, { daily_rules: daily, hourly_rules: hourly } ]
end
gap("hourly_weather", "gray leaf spot, northern corn leaf blight, rusts, Fusarium head blight and soybean rust need hourly T, RH and leaf wetness: NASA POWER hourly (pest_weather_rules.md) or the field station")
gap("rotation_pests", "corn rootworm and soybean cyst nematode, the Corn Belt pests rotation controls, have no documented rule or data source; pest_break scores only the family break")
gap("faw_arrival", "fall armyworm generations count from arrival, which needs FAMEWS or trap data")

# ---------------------------------------------------------------- 7 nitrogen (nutrient_removal.md)
# Field N balance per season = fertilizer N + fixed N - N removed in grain. Yields are water-limited (section 8).
heading "Nitrogen: applied, fixed and removed per strategy (kg N/ha over three seasons)"
# Rainfed yield from the season's water: FAO-56 soil water (TAW = 1000 x AWC x Zr, RAW = p x TAW) absorbs the
# rain deficit first (profile assumed full at planting, as Iowa springs usually leave it); what is left is
# stress, and FAO-33 turns it into a yield loss: 1 - Ya/Ym = Ky (1 - ETa/ETc).
AWC = Float(facts.fetch("available_water_capacity"))
water_factor = lambda do |key, n = need[key]|
  raw = input.("p.#{key}") * 1000 * AWC * input.("zr.#{key}")
  stress = [ n[:deficit_mm] - raw, 0 ].max
  eta = 1 - (stress / n[:crop_mm].to_f)
  { raw_mm: raw.round, stress_mm: stress.round, eta_etc: eta.round(3), yield_factor: (1 - (input.("ky.#{key}") * (1 - eta))).clamp(0, 1).round(3) }
end
water = need.keys.to_h { |k| [ k, water_factor.(k) ] }
water.each { |k, w| puts "#{short(k).ljust(10)} deficit #{need[k][:deficit_mm]} mm, soil buffer (RAW) #{w[:raw_mm]} mm, stress #{w[:stress_mm]} mm, ETa/ETc #{w[:eta_etc]}, yield x #{w[:yield_factor]}" }
season_rows = lambda do |crops|
  prev = history.last.last
  crops.map do |c|
    rate = c == CORN ? input.("n_rate.#{CORN}.#{legume.(prev) ? 'after_legume' : 'after_other'}") : input.("n_rate.#{c}")
    yld = input.("yield.#{c}") * water[c][:yield_factor]
    removed = yld * input.("n_removal.#{c}")
    fixed = legume.(c) ? removed * input.("fixation_share.#{c}") : 0
    prev = c
    { crop: short(c), key: c, n_applied: rate, n_fixed: fixed.round, n_removed: removed.round, yield_t_ha: yld.round(2) }
  end
end
nitrogen = strategies.to_h do |key, crops|
  rows = season_rows.(crops)
  applied, fixed, removed = %i[n_applied n_fixed n_removed].map { |f| rows.sum { |r| r[f] } }
  balance = applied + fixed - removed
  puts "#{key.ljust(13)} #{rows.map { |r| "#{r[:crop]} #{r[:n_applied].round}+#{r[:n_fixed]}-#{r[:n_removed]}" }.join('  ')}  " \
       "=> applied #{applied.round}, fixed #{fixed}, removed #{removed}, balance #{balance.round > 0 ? '+' : ''}#{balance.round}"
  [ key, { seasons: rows, applied: applied.round, fixed: fixed, removed: removed, balance: balance.round } ]
end
puts "(balance > 0: N left for leaching or the next crop; < 0: the soil is mined. Fixed N is a placeholder share.)"

# ---------------------------------------------------------------- 8 margin per strategy (the market sources)
heading "Margin per strategy, $/ha per year (rainfed yields from section 7; land rent left out: the same under all)"
margin_for = lambda do |crops, price_scale: {}|
  rows = season_rows.(crops).map do |r|
    revenue = r[:yield_t_ha] * input.("price.#{r[:key]}") * price_scale.fetch(r[:key], 1.0)
    cost = input.("cost.#{r[:key]}") + (r[:n_applied] * input.("n_price"))
    r.merge(revenue: revenue.round, cost: cost.round, margin: (revenue - cost).round)
  end
  { seasons: rows, margin_per_year: (rows.sum { |r| r[:margin] } / rows.size.to_f).round }
end
margins = strategies.to_h { |key, crops| [ key, margin_for.(crops) ] }
margins.each do |key, m|
  puts "#{key.ljust(13)} #{m[:seasons].map { |r| "#{r[:crop]} #{r[:yield_t_ha]}t $#{r[:revenue]}-$#{r[:cost]}=$#{r[:margin]}" }.join('  ')}  => $#{m[:margin_per_year]}/ha/yr " \
       "(#{m[:margin_per_year] - margins['current'][:margin_per_year] >= 0 ? '+' : ''}#{m[:margin_per_year] - margins['current'][:margin_per_year]} vs current)"
end
price_runs = { "corn -20%" => { CORN => 0.8 }, "corn +20%" => { CORN => 1.2 }, "soybean -20%" => { SOY => 0.8 }, "soybean +20%" => { SOY => 1.2 } }
price_sensitivity = price_runs.to_h do |label, scale|
  per = strategies.to_h { |key, crops| [ key, margin_for.(crops, price_scale: scale)[:margin_per_year] ] }
  puts "#{label.ljust(14)} #{per.map { |k, v| "#{k}=$#{v}" }.join('  ')}  best: #{per.max_by(&:last).first}"
  [ label, per ]
end
rank_score = compare.sort_by { |_, s| -s[:total] }.map(&:first)
rank_margin = margins.sort_by { |_, m| -m[:margin_per_year] }.map(&:first)
puts "Ranking by agronomic score: #{rank_score.join(' > ')}; by margin: #{rank_margin.join(' > ')}#{rank_score == rank_margin ? ' (they agree)' : ' (they differ: show both)'}"
gap("market", "margins use placeholder yields, prices and costs until NASS, AMS and ERS/ISU values go into ames_inputs.json")

# ---------------------------------------------------------------- 9 field station (DEVICES.md)
heading "Field station: which gap each sensor closes, and how much it matters here"
wind = [ 1.0, 2.0, 3.0, 4.0 ].to_h do |u2|
  series = et0_series.(u2)
  n = water_need.(CORN, series: series)
  w = water_factor.(CORN, n)
  puts "wind #{u2} m/s: Mar-May ET0 #{days.select { |x| (3..5).cover?(x.month) }.sum { |x| series[x] }.round} mm, corn ETc #{n[:crop_mm]} mm, deficit #{n[:deficit_mm]}, stress #{w[:stress_mm]}, yield x #{w[:yield_factor]}"
  [ u2, { corn_etc: n[:crop_mm], deficit: n[:deficit_mm], yield_factor: w[:yield_factor] } ]
end
wet = days.select { |x| corn_season.cover?(x) }.map { |x| [ x, d[x]["root_zone_soil_wetness"] ] }.select(&:last)
driest = wet.min_by(&:last)
puts "NASA POWER root-zone wetness (GWETROOT, 0-1) over the corn season: #{wet.map(&:last).min.round(2)}-#{wet.map(&:last).max.round(2)}, driest #{driest.first}"
DEVICE = [
  { sensor: "air T + RH (SHT45), hourly", closes: "hourly_weather", unlocks: "gray leaf spot, NCLB, rusts, FHB, soybean rust, Hutton; frost on the field, not the 0.5 deg grid", nasa: "POWER T2M, RH2M", metric: "bias and RMSE of daily Tmin/Tmax vs POWER; hours RH >= 90 vs POWER hourly" },
  { sensor: "soil moisture + T at 10 and 30 cm", closes: "soil water", unlocks: "the RAW buffer in section 7 measured instead of assumed full at planting; irrigation timing", nasa: "SMAP L4 root zone, POWER GWETROOT", metric: "correlation of daily anomalies (absolute values need the texture calibration DEVICES.md lists)" },
  { sensor: "tipping-bucket rain, 0.2 mm (Pro)", closes: "imerg", unlocks: "effective rain and heavy-day counts on the field; storm penalty in erosion", nasa: "POWER PRECTOTCORR, GPM IMERG", metric: "bias of event totals; hit rate for days >= 25 mm" },
  { sensor: "radiation (Pro)", closes: "-", unlocks: "Rs in ET0", nasa: "POWER ALLSKY_SFC_SW_DWN", metric: "bias of daily MJ/m2" },
  { sensor: "wind at 2 m: NOT in the spec", closes: "wind", unlocks: "U2 in ET0 (sensitivity above)", nasa: "POWER WS2M", metric: "add an anemometer on the SDI-12 port, or fetch WS2M" },
  { sensor: "leaf wetness: NOT in the spec", closes: "hourly_weather", unlocks: "the wetness hours every disease rule above counts (RH >= 90 is only a proxy)", nasa: "none", metric: "add a leaf-wetness sensor on the SDI-12 port" }
].freeze
DEVICE.each { |s| puts "- #{s[:sensor]}: #{s[:unlocks]}. Against #{s[:nasa]}: #{s[:metric]}" }

# ---------------------------------------------------------------- 10 landing page sample (app/helpers/landing_helper.rb)
heading "Landing page sample figures, recomputed"
landing_src = File.read(File.join(ROOT, "app/helpers/landing_helper.rb"))
claimed = ->(name) { landing_src[/#{name}: "?([\d.]+)"?/, 1]&.to_f }
heat30 = days.count { |x| d[x]["air_temp_max"] >= 30 }
heat32 = days.count { |x| d[x]["air_temp_max"] >= 32 }
landing = {
  "frost_days" => [ claimed.("frost_days"), season[:frost_days], "Tmin <= 0 C, #{days.first}..#{days.last}" ],
  "rain_mm" => [ claimed.("rain_mm"), season[:rain_mm], "NASA POWER precipitation, #{days.first}..#{days.last}" ],
  "gdd" => [ claimed.("gdd"), season[:gdd_simple_all], "simple method, daily T2M - 10 C, #{days.first}..#{days.last}; 86/50 gives #{season[:gdd_86_50_all]} (May-Sep #{season[:gdd_86_50_may_sep]})" ],
  "heat_days" => [ claimed.("heat_days"), heat32, "Tmax >= 32 C (>= 30 C gives #{heat30})" ],
  "slope" => [ claimed.("slope"), SLOPE_3DEP, "USGS 3DEP (derived)" ],
  "om" => [ claimed.("om"), Float(facts["organic_matter"]), "SSURGO" ],
  "sand" => [ claimed.("sand"), Float(facts["sand"]), "SSURGO" ],
  "clay" => [ claimed.("clay"), Float(facts["clay"]), "SSURGO" ],
  "awc" => [ claimed.("awc"), Float(facts["available_water_capacity"]), "SSURGO" ]
}
landing.each do |name, (shown, computed, how)|
  ok = shown && (shown - computed).abs <= [ 0.005 * shown.abs, 0.5 ].max
  puts "#{name.ljust(10)} shown #{shown.inspect.ljust(7)} computed #{computed.inspect.ljust(7)} #{ok ? 'ok' : 'DIFFERS'}  (#{how})"
  check("landing #{name} matches the data", ok, "shown #{shown}, computed #{computed}")
end

# ---------------------------------------------------------------- 11 output and checks
check("yield factors are between 0 and 1", water.values.all? { |w| w[:yield_factor].between?(0, 1) })
check("soil buffer uses the SSURGO AWC of this field", AWC == Float(facts["available_water_capacity"]), "AWC #{AWC} cm/cm")
check("more wind, more ET0 (FAO-56 Eq. 6 is monotonic in u2 for es > ea)", wind.values.each_cons(2).all? { |a, b| b[:corn_etc] >= a[:corn_etc] })
check("every strategy has a margin and a nitrogen balance", strategies.keys.all? { |k| margins[k] && nitrogen[k] })
check("every input used is tagged and sourced", used.values.all? { |i| %w[placeholder published cited provided].include?(i[:status]) && !i[:source].to_s.empty? })

File.write(OUT_PATH, JSON.pretty_generate({
  field: { lat: lat, lon: lon, elevation_m: ELEV, slope_3dep: SLOPE_3DEP, slope_ssurgo: SLOPE_SSURGO, cdl: cdl, soil: facts.slice(*%w[soil_map_unit organic_matter sand clay available_water_capacity hydrologic_soil_group drainage_class]) },
  assumptions: { wind_u2: WIND.empty? ? U2 : "NASA POWER WS2M daily (mean #{(days.sum { |x| WIND.fetch(x, U2) } / days.size).round(2)} m/s)", profile: PROFILE },
  monthly: monthly, season: season, need: need, weights: weights, compare: compare, sensitivity: sensitivity,
  timeline: { risks: risk_strip, lines: lines },
  pests: { tar_spot: { favourable_days: tar.size, season_days: corn_season.count, first: tar.first, longest_run: tar_runs.max || 0, rh90_days: humid }, fall_armyworm: faw, strategies: pests },
  water_limited: water, nitrogen: nitrogen, margins: margins, price_sensitivity: price_sensitivity,
  ranking: { score: rank_score, margin: rank_margin }, device: { sensors: DEVICE, wind_sensitivity: wind },
  inputs: used, landing: landing, gaps: GAPS, checks: CHECKS
}))

heading "Inputs not in the CSV (replace the placeholders through #{File.basename(inputs_path)})"
used.group_by { |_, i| i[:status] }.each do |status, list|
  puts "#{status} (#{list.size}): #{list.map { |k, i| "#{k}=#{i[:value]}" }.join(', ')}"
end
heading "Gaps (what the numbers above do not rest on)"
GAPS.each { |g| puts "- #{g[:gap]}: #{g[:why]}" }
heading "Checks"
CHECKS.each { |c| puts "#{c[:ok] ? 'PASS' : 'FAIL'}  #{c[:check]}#{"  (#{c[:detail]})" if c[:detail] && !c[:detail].to_s.empty?}" }
puts "\nWrote #{OUT_PATH}"
exit(CHECKS.all? { |c| c[:ok] } ? 0 : 1)
