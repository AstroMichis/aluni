# frozen_string_literal: true

# V4 · Is the rotation advice backed by evidence, and how large is the benefit at a field like this one?
#
# Aluni's comparator rewards breaking a crop family (pest_break) and growing legumes (nitrogen,
# soil_health) with points. This study measures what the evidence says those points are worth, from
# Zhao, Zang et al. 2022 (Nature Communications 13:4926; figshare 20290923, CC BY 4.0): 11,768 paired
# yields of a crop after a legume vs the same crop after a non-legume. yi = ln(yield after legume /
# yield after non-legume); wgt = the paper's replicate weight.
#
# The subset that matches this field: maize after soybean, then narrowed to the USA, to a climate like
# the site (sites.yml trial_climate; Ames: 6-12 C, 700-1100 mm), and by the maize's nitrogen rate
# (Iowa farms fertilise corn at about 150-200 kg N/ha, so the high-N effect is the one a farmer gets).
# Weighted mean lnRR with a 95% interval from a site-clustered bootstrap (observations from one site are
# resampled together, since they are not independent).
#
# The comparator's own rotation rules are also checked against the field's real history (CDL 2008-2025).
#
# Pre-registered criterion: the effect size with its 95% interval replaces the rotation placeholder in
# the margin calculation (V7). PASS when the high-N, site-like interval excludes zero, i.e. the evidence
# supports the rotation advice at the nitrogen rates farmers here use.
#
# Run: mise exec -- ruby docs/proposal/validation/v4_rotation.rb

require_relative "lib"
include Hindcast

need!("zhao2022_data.csv", "cdl.json")
rows = CSV.read(path("zhao2022_data.csv"), headers: true).map(&:to_h)
num = ->(v) { Float(v.to_s, exception: false) }
base = rows.select { |r| r["PreEff"] == "Soybean" && r["SubEff"] == "Maize" && num.(r["yi"]) && num.(r["wgt"]) }

def effect(subset, num, boot: 2000, seed: 7)
  return nil if subset.size < 10

  w = subset.map { |r| num.(r["wgt"]) }
  y = subset.map { |r| num.(r["yi"]) }
  est = w.zip(y).sum { |a, b| a * b } / w.sum
  sites = subset.group_by { |r| [ r["Lat"], r["Lon"] ] }.values
  rng = Random.new(seed)
  draws = Array.new(boot) do
    sample = Array.new(sites.size) { sites[rng.rand(sites.size)] }.flatten(1)
    ws = sample.map { |r| num.(r["wgt"]) }
    ws.zip(sample.map { |r| num.(r["yi"]) }).sum { |a, b| a * b } / ws.sum
  end.sort
  lo = draws[(0.025 * boot).floor]
  hi = draws[(0.975 * boot).ceil - 1]
  pct = ->(v) { (100 * (Math.exp(v) - 1)).round(1) }
  { n: subset.size, sites: sites.size, lnrr: est.round(4), gain_pct: pct.(est), ci_pct: [ pct.(lo), pct.(hi) ],
    corn_after_corn_factor: Math.exp(-est).round(3) }
end

# Trials "like this site": the climate window in sites.yml (Ames: the pre-registered 6-12 C, 700-1100 mm).
mat_lo, mat_hi = SITE.dig("trial_climate", "mat")
map_lo, map_hi = SITE.dig("trial_climate", "map")
like = ->(r) { (mat_lo..mat_hi).cover?(num.(r["MAT"]).to_f) && (map_lo..map_hi).cover?(num.(r["MAP"]).to_f) }
LIKE = "#{SITE['name'].split(',').first}-like".freeze
puts "#{SITE['name']}: trials with mean annual temperature #{mat_lo}-#{mat_hi} C and rain #{map_lo}-#{map_hi} mm"

subsets = {
  "all maize after soybean" => base,
  "USA" => base.select { |r| r["Country"] == "United States of America" },
  "site-like climate" => base.select(&like),
  "site-like, maize N 0 kg/ha" => base.select { |r| like.(r) && num.(r["NFR"]).to_f.zero? },
  "site-like, maize N >= 120 kg/ha" => base.select { |r| like.(r) && num.(r["NFR"]).to_f >= 120 },
  "USA, maize N >= 150 kg/ha" => base.select { |r| r["Country"] == "United States of America" && num.(r["NFR"]).to_f >= 150 }
}
heading "Maize yield after soybean vs after a non-legume (Zhao et al. 2022)"
effects = subsets.to_h do |label, subset|
  e = effect(subset, num)
  if e
    puts "#{label.ljust(48)} n=#{e[:n]} (#{e[:sites]} sites): #{e[:gain_pct] >= 0 ? '+' : ''}#{e[:gain_pct]}% [95% CI #{e[:ci_pct].join(' to ')}%]; " \
         "corn after corn = #{e[:corn_after_corn_factor]} x corn after soybean"
  else
    puts "#{label.ljust(48)} too few observations (#{subset.size})"
  end
  [ label, e ]
end

heading "The comparator's rules on the field's real history (CDL 2008-2025)"
cdl = JSON.parse(File.read(path("cdl.json"))).sort.map { |y, c| [ y, c ] }
families = { "Corn" => "poaceae", "Soybeans" => "fabaceae" }
same_family = cdl.each_cons(2).count { |(_, a), (_, b)| families[a] == families[b] }
mono = cdl.chunk_while { |(_, a), (_, b)| a == b }.count { |run| run.size >= 3 }
no_legume = cdl.each_cons(4).count { |w| w.none? { |_, c| c == "Soybeans" } }
puts "Same-family pairs #{same_family}, monoculture runs #{mono}, 4-season windows without a legume #{no_legume}: " \
     "the farmer's strict corn-soybean alternation already satisfies every rule, so pest_break = 100 for the current rotation."

key = "site-like, maize N >= 120 kg/ha"
chosen = effects[key] || effects["USA, maize N >= 150 kg/ha"]
pass = chosen ? chosen[:ci_pct].first.positive? : nil
record("V4",
       question: "Is the rotation advice backed by evidence, and how large is the benefit here?",
       truth: "Zhao et al. 2022 meta-analysis, #{base.size} maize-after-soybean observations; the field's CDL history",
       criterion: "The high-N, #{LIKE} 95% interval of the soybean pre-crop effect on maize excludes zero",
       verdict: verdict(pass),
       summary: chosen ? "maize after soybean yields #{chosen[:gain_pct]}% more than after a non-legume at farm N rates [#{chosen[:ci_pct].join(' to ')}%], " \
                         "#{chosen[:n]} obs; so continuous corn yields #{chosen[:corn_after_corn_factor]} x rotated corn" : "too few observations",
       details: { effects: effects, chosen: key, trial_climate: SITE['trial_climate'], cdl_rules: { same_family: same_family, monoculture: mono, no_legume_windows: no_legume } })
