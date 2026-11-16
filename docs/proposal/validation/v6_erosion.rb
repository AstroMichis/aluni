# frozen_string_literal: true

# V6 · How much soil does each rotation lose, and how much does a cover crop save?
#
# The proposal counts "exposed bare months"; the app's erosion score is a points heuristic
# (100 - row crops x 8 or 25, -7 for 50 mm storms). Neither is a soil loss. This study computes one with
# RUSLE (Renard et al. 1997, USDA Agriculture Handbook 703), A = R x K x LS x C x P, on the field's own
# data, and checks whether the heuristic ranks the three strategies the same way.
#
#   R  rainfall erosivity from annual rain, Renard and Freimund (1994):
#        R = 0.0483 P^1.61 (P <= 850 mm), R = 587.8 - 1.219 P + 0.004105 P^2 (P > 850 mm), MJ mm ha-1 h-1 yr-1;
#      its monthly split follows the daily erosive rain (>= 12.7 mm) raised to 1.81 (Richardson et al. 1983).
#   K  SSURGO surface kwfact (US units) x 0.1317 (to SI)
#   LS McCool et al. (1987, 1989) with the SSURGO USLE slope length; slope from 3DEP and from SSURGO
#   C  daily soil-loss ratio averaged by the erosivity of each day: SLR = CC x SC,
#        CC = 1 - fc exp(-0.1 H)    canopy cover (AH-703 Eq. 5-4), fc from FAO-56 Eq. 76 on the Kc curve
#        SC = exp(-0.035 Rc)        residue cover Rc in % (AH-703, b = 0.035)
#   P  1 (no contouring or terraces)
#
# Inputs that are assumptions, not data, are tagged ASSUMPTION in the output (residue cover, cover-crop
# canopy, canopy fall height). Pre-registered criterion: the study PASSES as a check of the app's erosion
# score when RUSLE ranks the three strategies in the same order as the score (higher score = less loss).
# The comparison with published Iowa soil-loss figures needs a documented source (not yet in
# docs/data_sources/), so that part is reported as BLOCKED.
#
# Run: mise exec -- ruby docs/proposal/validation/v6_erosion.rb

require_relative "lib"
include Hindcast

need!("ssurgo_erosion.json")
header, *rows = JSON.parse(File.read(path("ssurgo_erosion.json")))["Table"]
soil = rows.map { |r| header.zip(r).to_h }.min_by { |r| r["hzdept_r"].to_i }
K = Float(soil["kwfact"]) * 0.1317
LAMBDA = Float(soil["slopelenusle_r"]) # m
T_FACTOR = Float(soil["tfact"]) * 2.2417 # t/acre/yr -> t/ha/yr
SLOPES = { "3DEP 4.05%" => 4.05, "SSURGO #{soil['slope_r']}%" => Float(soil["slope_r"]) }.freeze

ASSUMPTION = {
  # Residue cover left on the surface after harvest, % (reduced tillage). Source to document: NRCS / ISU residue guides.
  "residue" => { CORN => 50.0, SOY => 20.0, WHEAT => 40.0, SUN => 20.0 },
  # Effective canopy fall height, m: half the FAO-56 Table 12 maximum crop height (maize 2, soybean 0.5-1, wheat 1, sunflower 2).
  "fall_height" => { CORN => 1.0, SOY => 0.4, WHEAT => 0.5, SUN => 1.0 },
  # Cereal rye cover crop: canopy cover reached 60 days after sowing (it grows little in winter).
  "cover_fc" => 0.5, "cover_ramp_days" => 60
}.freeze
FAO_HEIGHT = { CORN => 2.0, SOY => 0.75, WHEAT => 1.0, SUN => 2.0 }.freeze

def ls_factor(slope_pct)
  theta = Math.atan(slope_pct / 100.0)
  beta = (Math.sin(theta) / 0.0896) / ((3 * (Math.sin(theta)**0.8)) + 0.56)
  m = beta / (1 + beta)
  s = slope_pct < 9 ? (10.8 * Math.sin(theta)) + 0.03 : (16.8 * Math.sin(theta)) - 0.50
  ((LAMBDA / 22.13)**m) * s
end

def r_factor(annual_mm)
  annual_mm <= 850 ? 0.0483 * (annual_mm**1.61) : 587.8 - (1.219 * annual_mm) + (0.004105 * (annual_mm**2))
end

# Daily erosivity weights over a typical year (day of year 1..365) from Daymet 2001-2025.
dm = daymet
years = (2001..2025).to_a
annual = mean(years.map { |y| dm.select { |d, _| d.year == y }.sum { |_, v| v[:rain] } })
R = r_factor(annual)
weight = Array.new(366, 0.0)
dm.each { |d, v| weight[[ d.yday, 365 ].min] += v[:rain]**1.81 if v[:rain] >= 12.7 }
total_w = weight.sum
weight.map! { |w| w / total_w }
monthly_share = (1..12).to_h { |m| [ m, (1..365).select { |j| Date.ordinal(2025, j).month == m }.sum { |j| weight[j] }.round(3) ] }

# Canopy fraction on day i of a crop season, FAO-56 Eq. 76 on the Kc curve (Kcb taken as Kc - 0.05 above the initial value).
def canopy(key, i)
  fao = AGRONOMY.dig(key, "fao56")
  k = kc(i, fao["kc"], fao["stages"])
  kmin = fao["kc"][0]
  kmax = fao["kc"][1] + 0.05
  (((k - kmin) / (kmax - kmin)).clamp(0, 1))**(1 + (0.5 * FAO_HEIGHT[key]))
end

# Soil-loss ratio for each day of three seasons (1095 days) for a crop sequence, with or without a
# cereal rye cover crop sown the day after each harvest and ended at the next planting.
def slr_line(crops, cover:)
  line = Array.new(365 * 3)
  prev = nil
  crops.each_with_index do |crop, s|
    fao = AGRONOMY.dig(crop, "fao56")
    start = (s * 365) + Date.new(2025, fao["planting_month"], 1).yday - 1
    len = fao["stages"].sum
    len.times { |i| line[start + i] = { crop: crop, fc: canopy(crop, i) } if start + i < line.size }
    prev = crop
  end
  residue_of = crops.first
  since_harvest = nil
  line.each_with_index.map do |day, i|
    if day
      residue_of = day[:crop]
      since_harvest = 0
      h = ASSUMPTION["fall_height"][day[:crop]]
      cc = 1 - (day[:fc] * Math.exp(-0.1 * h))
      # Residue under a growing crop: the previous crop's, taken as decayed to half.
      cc * Math.exp(-0.035 * ASSUMPTION["residue"][residue_of] * 0.5)
    else
      since_harvest = since_harvest.nil? ? 120 : since_harvest + 1
      sc = Math.exp(-0.035 * ASSUMPTION["residue"][residue_of])
      fc = cover ? ASSUMPTION["cover_fc"] * [ since_harvest / ASSUMPTION["cover_ramp_days"].to_f, 1 ].min : 0
      (1 - (fc * Math.exp(-0.1 * 0.3))) * sc
    end
  end
end

def c_factor(line, weight) = line.each_with_index.sum { |slr, i| slr * weight[(i % 365) + 1] } / 3.0

strategies = { "current" => [ SOY, CORN, SOY ], "small_grain" => [ WHEAT, SOY, CORN ], "other_family" => [ SUN, CORN, SUN ] }
app_erosion = { "current" => 76, "small_grain" => 84, "other_family" => 76 } # worked example, 3DEP slope, no storm penalty

heading "RUSLE inputs"
puts "R #{R.round} MJ mm/(ha h yr) from #{annual.round} mm/yr (Daymet 2001-2025); K #{K.round(4)} (kwfact #{soil['kwfact']}); " \
     "slope length #{LAMBDA} m; T #{T_FACTOR.round(1)} t/ha/yr"
puts "Erosivity share by month: #{monthly_share.select { |_, v| v >= 0.01 }}"
puts "LS: #{SLOPES.map { |k, s| "#{k} -> #{ls_factor(s).round(2)}" }.join(', ')}"

results = {}
SLOPES.each do |label, slope|
  heading "Soil loss, t/ha/yr, slope #{label}"
  ls = ls_factor(slope)
  results[label] = strategies.to_h do |key, crops|
    bare = R * K * ls * c_factor(slr_line(crops, cover: false), weight)
    covered = R * K * ls * c_factor(slr_line(crops, cover: true), weight)
    row = { no_cover: bare.round(2), with_cover: covered.round(2), saved_pct: (100 * (bare - covered) / bare).round,
            over_t: bare > T_FACTOR }
    puts "#{key.ljust(13)} no cover #{row[:no_cover]}  with rye cover #{row[:with_cover]}  saved #{row[:saved_pct]}%  " \
         "#{row[:over_t] ? 'ABOVE' : 'below'} the T factor #{T_FACTOR.round(1)}"
    [ key, row ]
  end
end

base = results.values.first
rusle_order = base.sort_by { |_, r| r[:no_cover] }.map(&:first)
score_order = app_erosion.sort_by { |k, v| [ -v, rusle_order.index(k) ] }.map(&:first)
ties = app_erosion.values.tally.select { |_, n| n > 1 }.keys
consistent = rusle_order.each_cons(2).all? { |a, b| app_erosion[a] >= app_erosion[b] }
puts "\nRUSLE order (least loss first): #{rusle_order.join(' > ')}; app erosion score #{app_erosion} " \
     "#{consistent ? 'is consistent with it' : 'ranks them differently'}#{" (the score ties #{ties.join(', ')})" if ties.any?}"
record("V6",
       question: "How much soil does each rotation lose, and how much does a cover crop save?",
       truth: "RUSLE (AH-703) on Daymet rain, SSURGO K and slope length, 3DEP and SSURGO slope; published #{SITE['state_name']} figures not yet documented",
       criterion: "The app's erosion score orders the strategies as RUSLE does (higher score = less soil loss)",
       verdict: verdict(consistent),
       summary: "#{base.map { |k, r| "#{k} #{r[:no_cover]} -> #{r[:with_cover]} t/ha/yr (-#{r[:saved_pct]}%)" }.join('; ')} on the 3DEP slope; " \
                "T = #{T_FACTOR.round(1)}; score order #{consistent ? 'matches' : 'differs from'} RUSLE",
       details: { r: R.round, k: K.round(4), lambda_m: LAMBDA, t_factor: T_FACTOR.round(1), erosivity_by_month: monthly_share,
                  results: results, rusle_order: rusle_order, app_erosion: app_erosion, assumptions: ASSUMPTION,
                  blocked: "comparison with published #{SITE['state_name']} soil-loss figures (source to document)" })
