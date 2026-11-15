# frozen_string_literal: true

# Writes config/evidence/backtest.yml, the snapshot the public /evidence page renders (EvidenceController),
# from validation_out.json and claims_audit. Only numbers go in; every sentence around them is in the
# locale files (config/locales/{en,es}/views/*.evidence.yml), so the page stays bilingual.
#
# Run after the studies: mise exec -- ruby docs/proposal/validation/run_all.rb && mise exec -- ruby docs/proposal/validation/publish.rb

require "date"
require "json"
require "yaml"

dir = __dir__
v = JSON.parse(File.read(File.join(dir, "validation_out.json")))
out = File.expand_path("../../../config/evidence/backtest.yml", dir)
d = ->(id) { v.fetch(id).fetch("details") }
pct = ->(x) { x.round }

v1 = d.("V1")
seasons = v1["seasons"]
power_within = seasons.count { |s| s["power_err"].abs <= 15 }
imerg_within = seasons.count { |s| s["imerg_err"].abs <= 15 }
v2 = d.("V2")
corn = v2["zea-mays"]
soy = v2["glycine-max"]
v3 = d.("V3")
water_rank = v3["water_mean_factor"].sort_by { |_, f| -f }.map(&:first)
v4 = d.("V4")
chosen = v4["effects"][v4["chosen"]]
no_n = v4["effects"]["Ames-like, maize N 0 kg/ha"]
v5 = d.("V5")
rhos = v5["correlations"].values.flat_map { |c| [ c["rho"], c["rho_share"] ] }.compact # raw losses and their share of weather losses
v6 = d.("V6")
base = v6["results"].values.first
v7 = d.("V7")
planted = v7["operations"].values.filter_map { |o| o["corn_50pct_planted"] && Date.parse(o["corn_50pct_planted"]) }
v8 = d.("V8")

snapshot = {
  "generated_on" => Date.today.iso8601,
  "field" => { "lat" => 42.0, "lon" => -93.75, "place" => "Story County, Iowa", "from" => 2001, "to" => 2025 },
  "summary" => v.transform_values { |r| r["verdict"].to_s.split.first }.sort.to_h,
  "studies" => {
    "v1" => { "verdict" => "FAIL", "tmax_rmse" => v1.dig("temperature", "tmax", "rmse"), "tmin_rmse" => v1.dig("temperature", "tmin", "rmse"),
              "frost_agreement" => pct.(v1["frost_agreement_pct"]), "gauges" => v1["gauges"], "seasons" => seasons.size,
              "power_low_seasons" => seasons.count { |s| s["power_err"].negative? },
              "power_bias" => (seasons.sum { |s| s["power_err"] } / seasons.size).abs.round(1),
              "power_within" => pct.(100.0 * power_within / seasons.size), "imerg_within" => pct.(100.0 * imerg_within / seasons.size),
              "power_hit" => v1.dig("heavy_days", "POWER", "hit_rate"), "imerg_hit" => v1.dig("heavy_days", "IMERG", "hit_rate") },
    "v2" => { "verdict" => "FAIL", "r_corn" => corn.dig("scored", "POWER", "pearson_vs_nass"), "r_soy" => soy.dig("scored", "POWER", "pearson_vs_nass"),
              "rho_corn" => corn.dig("scored", "POWER", "spearman_vs_rma_drought"), "rho_soy" => soy.dig("scored", "POWER", "spearman_vs_rma_drought"),
              "stressed_min" => [ corn, soy ].map { |c| c.dig("scored", "POWER", "stressed_years").size }.min,
              "stressed_max" => [ corn, soy ].map { |c| c.dig("scored", "POWER", "stressed_years").size }.max,
              "soy_2025" => soy.dig("nass_anomaly", "2025") },
    "v3" => { "verdict" => "FAIL", "suitability" => v3.dig("gaez", "zea-mays", "suit_high").to_i, "crops" => v3["gaez"].size + v3["gaez_other"].size,
              "water_first" => water_rank.first(2), "maize_gap" => v3.dig("gaez_vs_nass", "zea-mays", "diff_pct"),
              "soy_gap" => v3.dig("gaez_vs_nass", "glycine-max", "diff_pct") },
    "v4" => { "verdict" => "PASS", "gain" => chosen["gain_pct"], "low" => chosen["ci_pct"][0], "high" => chosen["ci_pct"][1],
              "trials" => chosen["n"], "sites" => chosen["sites"], "gain_no_n" => no_n["gain_pct"] },
    "v5" => { "verdict" => "REPORTED", "rho_min" => rhos.min, "rho_max" => rhos.max, "rules" => v5["correlations"].size,
              "lead" => v5["lead"].map { |l| l["lead_months"] }.sort[v5["lead"].size / 2] },
    "v6" => { "verdict" => "PASS", "saved_min" => base.values.map { |r| r["saved_pct"] }.min, "saved_max" => base.values.map { |r| r["saved_pct"] }.max,
              "loss_min" => base.values.map { |r| r["no_cover"] }.min.round, "loss_max" => base.values.map { |r| r["no_cover"] }.max.round,
              "t_factor" => v6["t_factor"] },
    "v7" => { "verdict" => "FAIL", "years" => v7["years"].size, "aluni" => v7.dig("totals", "aluni"), "farmer" => v7.dig("totals", "farmer"),
              "corn_always" => v7.dig("totals", "corn_always"), "foresight" => v7.dig("totals", "foresight"),
              "springs" => v7["operations"].size, "short_springs" => v7["operations"].count { |_, o| !o["enough"] },
              "planted_first" => planted.min_by(&:yday)&.strftime("%m-%d"), "planted_last" => planted.max_by(&:yday)&.strftime("%m-%d") },
    "v8" => { "verdict" => "FAIL", "agreement" => v8["agreement_pct"], "months" => v8.dig("by_month").values.compact.sum { |m| m["n"] },
              "edges" => v8["edges_pct"], "lag" => v8["lag_months"], "nov_dec_open" => v8["nov_dec_open"], "nov_dec_views" => v8["nov_dec_views"],
              "app_rule_agreement" => v8["app_rule_agreement_pct"] }
  }
}
header = "# Snapshot of the hindcast (docs/proposal/validation), rendered by /evidence. Generated by\n" \
         "# docs/proposal/validation/publish.rb; do not edit by hand. Numbers only: the words are in the locale files.\n"
Dir.mkdir(File.dirname(out)) unless Dir.exist?(File.dirname(out))
File.write(out, header + snapshot.to_yaml.sub(/\A---\n/, ""))
puts "Wrote #{out}"
puts snapshot["studies"].map { |k, s| "#{k}: #{s.reject { |kk, _| kk == 'verdict' }.first(4).map { |kk, vv| "#{kk}=#{vv}" }.join(' ')}" }
