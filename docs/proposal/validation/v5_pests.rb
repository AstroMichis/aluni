# frozen_string_literal: true

# V5 · Do the pest and disease weather rules line up with real losses?
#
# The rules documented in docs/data_sources/pest_weather_rules.md are run on NASA POWER at the pin,
# every season 2001-2025: hourly T and RH for the corn leaf diseases, daily T for tar spot and fall
# armyworm. They are scored against USDA RMA insured losses caused by Plant Disease (81) + Mycotoxin (82)
# and by Insects (71), for corn and soybeans in the twelve counties of the NASS Central Iowa district
# (Story County alone has too few disease claims to rank).
#
# How each published rule is turned into a daily test (an operationalisation, stated so it can be argued):
#   gray leaf spot   >= 11 h with RH >= 90% in the day, and the day's maximum T within 25-31 C
#   N. corn leaf blight >= 6 h with RH >= 90% while T is within 18-24 C
#   tar spot         30-day mean T within 18-23 C, 15 Jun-15 Sep
#   fall armyworm    degree-days May-Oct above 12.57 C (du Plessis 2020)
# RH >= 90% stands in for leaf wetness, which POWER does not measure (the gap the Sonda would close).
#
# Pre-registered criterion: none to pass or fail. The study reports the rank correlation (Spearman, with
# a permutation p-value) between each rule's season count and the matching losses, and the lead time from
# the first favourable day to the month losses are recorded. A weak link is a valid result.
#
# Run: mise exec -- ruby docs/proposal/validation/v5_pests.rb

require_relative "lib"
include Hindcast

YEARS = (2001..2025).to_a
CENTRAL = %w[Boone Dallas Grundy Hamilton Hardin Jasper Marshall Polk Poweshiek Story Tama Webster].freeze
power = power_daily

hourly = YEARS.to_h do |y|
  need!("power_hourly/#{y}.json")
  p = JSON.parse(File.read(path("power_hourly/#{y}.json"))).dig("properties", "parameter")
  [ y, p["T2M"].keys.group_by { |k| Date.strptime(k[0, 8], "%Y%m%d") }.transform_values do |keys|
    keys.filter_map { |k| (t = p["T2M"][k]) && (rh = p["RH2M"][k]) && t > -999 && rh > -999 ? [ t, rh ] : nil }
  end ]
end

counts = YEARS.to_h do |y|
  days = hourly[y]
  gls = days.select { |_, hs| hs.count { |_, rh| rh >= 90 } >= 11 && (25..31).cover?(hs.map(&:first).max.to_f) }.keys
  nclb = days.select { |_, hs| hs.count { |t, rh| rh >= 90 && (18..24).cover?(t) } >= 6 }.keys
  window = (Date.new(y, 6, 15)..Date.new(y, 9, 15)).to_a
  tar = window.select do |d|
    ts = (0..29).filter_map { |i| power[d - i]&.dig(:tmean) }
    ts.size == 30 && mean(ts).between?(18, 23)
  end
  faw = (Date.new(y, 5, 1)..Date.new(y, 10, 31)).sum { |d| v = power[d]; v && v[:tmax] && v[:tmin] ? [ ((v[:tmax] + v[:tmin]) / 2) - 12.57, 0 ].max : 0 }
  [ y, { gls: gls.size, gls_first: gls.min, nclb: nclb.size, nclb_first: nclb.min, tar: tar.size, tar_first: tar.min,
        faw_dd: faw.round, rh90_hours: days.values.sum { |hs| hs.count { |_, rh| rh >= 90 } } } ]
end

losses = YEARS.to_h do |y|
  rows = rma(y).select { |r| CENTRAL.include?(r[:county].to_s.strip.split.map(&:capitalize).join(" ")) }
  [ y, { "0041" => "corn", "0081" => "soybeans" }.to_h do |code, name|
    rs = rows.select { |r| r[:commodity_code] == code }
    weather = rs.reject { |r| r[:cause].to_s.match?(/price|ARPI|Area|All Other/i) }.sum { |r| r[:indemnity] }
    disease = rs.select { |r| %w[81 82].include?(r[:cause_code]) }
    insects = rs.select { |r| r[:cause_code] == "71" }
    [ name, { disease: disease.sum { |r| r[:indemnity] }.round, insects: insects.sum { |r| r[:indemnity] }.round, weather: weather.round,
             disease_months: disease.map { |r| r[:month_code].to_i }.tally, insect_months: insects.map { |r| r[:month_code].to_i }.tally } ]
  end ]
end

heading "Season counts at the pin and Central Iowa insured losses"
puts "year  GLS days  NCLB days  tar-spot days  FAW DD | corn disease $  corn insects $  soy disease $  soy insects $"
YEARS.each do |y|
  c = counts[y]
  l = losses[y]
  printf("%d  %8d  %9d  %13d  %6d | %14d  %14d  %13d  %13d\n", y, c[:gls], c[:nclb], c[:tar], c[:faw_dd],
         l["corn"][:disease], l["corn"][:insects], l["soybeans"][:disease], l["soybeans"][:insects])
end

heading "Rank correlation of each rule with the losses it should explain"
tests = {
  "gray leaf spot -> corn disease" => [ :gls, "corn", :disease ],
  "N. corn leaf blight -> corn disease" => [ :nclb, "corn", :disease ],
  "tar spot -> corn disease" => [ :tar, "corn", :disease ],
  "fall armyworm DD -> corn insects" => [ :faw_dd, "corn", :insects ],
  "RH >= 90% hours -> soybean disease" => [ :rh90_hours, "soybeans", :disease ]
}
# Disease share of all weather-caused losses removes the year-to-year swing in prices and insured acres.
correlations = tests.to_h do |label, (rule, crop, kind)|
  x = YEARS.map { |y| counts[y][rule].to_f }
  y_abs = YEARS.map { |y| losses[y][crop][kind].to_f }
  y_share = YEARS.map { |y| w = losses[y][crop][:weather]; w.positive? ? losses[y][crop][kind].to_f / w : 0.0 }
  rho = spearman(x, y_abs)
  rho_share = spearman(x, y_share)
  out = { rho: rho&.round(2), p: rho ? permutation_p(x, y_abs, stat: :spearman).round(3) : nil,
          rho_share: rho_share&.round(2), p_share: rho_share ? permutation_p(x, y_share, stat: :spearman).round(3) : nil,
          loss_years: YEARS.count { |y| losses[y][crop][kind].positive? } }
  puts "#{label.ljust(38)} rho #{out[:rho]} (p=#{out[:p]}); as share of weather losses rho #{out[:rho_share]} (p=#{out[:p_share]}); years with losses #{out[:loss_years]}"
  [ label, out ]
end

heading "Lead time: first favourable day vs the month insured disease losses are dated"
lead = YEARS.filter_map do |y|
  months = losses[y]["corn"][:disease_months]
  next if months.empty? || counts[y][:gls_first].nil? && counts[y][:tar_first].nil?

  first = [ counts[y][:gls_first], counts[y][:tar_first] ].compact.min
  loss_month = months.max_by(&:last).first
  { year: y, first_favourable: first, main_loss_month: loss_month, lead_months: loss_month - first.month }
end
lead.each { |l| puts "#{l[:year]}: first favourable #{l[:first_favourable]}, losses mostly dated #{Date::ABBR_MONTHNAMES[l[:main_loss_month]]} (#{l[:lead_months]} months later)" }
median_lead = lead.empty? ? nil : lead.map { |l| l[:lead_months] }.sort[lead.size / 2]

strong = correlations.select { |_, c| c[:rho].to_f >= 0.4 && c[:p].to_f <= 0.05 }.keys
record("V5",
       question: "Do the pest and disease weather rules line up with real losses?",
       truth: "USDA RMA insured losses to plant disease, mycotoxin and insects, NASS Central Iowa district, 2001-2025",
       criterion: "Reported, not scored: Spearman rho with a permutation p-value per rule, and the lead time",
       verdict: "REPORTED",
       summary: "#{strong.empty? ? 'no rule' : strong.join(', ')} reached rho >= 0.4 at p <= 0.05; " \
                "median lead from the first favourable day to the main loss month #{median_lead || 'n/a'} months",
       details: { counts: counts, losses: losses, correlations: correlations, lead: lead, counties: CENTRAL })
