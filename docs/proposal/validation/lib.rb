# frozen_string_literal: true

# Shared code for the hindcast studies (v1_*.rb ... v8_*.rb): the data readers, the FAO-56 and FAO-33
# formulas (the same as docs/proposal/ames_worked_example.rb, which the app's services cross-check),
# the statistics, and the result file. Plain Ruby; data come from fetch.rb.

require "csv"
require "date"
require "json"
require "yaml"

module Hindcast
  ROOT = File.expand_path("../../..", __dir__)
  SITES = YAML.safe_load_file(File.expand_path("sites.yml", __dir__))
  SITE_KEY = ENV.fetch("SITE", "ames")
  SITE = SITES.fetch(SITE_KEY) { abort "unknown SITE #{SITE_KEY}; sites.yml has #{SITES.keys.join(', ')}" }
  DATA = File.expand_path("data/#{SITE_KEY}", __dir__)
  OUT = File.expand_path(SITE_KEY == "ames" ? "validation_out.json" : "validation_out_#{SITE_KEY}.json", __dir__)
  LAT = SITE.fetch("lat")
  LON = SITE.fetch("lon")
  AGRONOMY = YAML.safe_load_file(File.join(ROOT, "config/crops/agronomy.yml"))
  CORN = "zea-mays"
  SOY = "glycine-max"
  WHEAT = "triticum-aestivum"
  SUN = "helianthus-annuus"
  # FAO-56 Table 22 (p, lower bound of the maximum root depth) and FAO-33 Table 24 (seasonal Ky),
  # the same values as the worked example's INPUTS.
  P = { CORN => 0.55, SOY => 0.50, WHEAT => 0.55, SUN => 0.45 }.freeze
  ZR = { CORN => 1.0, SOY => 0.6, WHEAT => 1.0, SUN => 0.8 }.freeze
  ZR_MAX = { CORN => 1.7, SOY => 1.3, WHEAT => 1.5, SUN => 1.5 }.freeze
  KY = { CORN => 1.25, SOY => 0.85, WHEAT => 1.15, SUN => 0.95 }.freeze
  SIGMA = 4.903e-9
  GSC = 0.0820
  ALBEDO = 0.23

  class Blocked < StandardError; end

  module_function

  def path(name) = File.join(DATA, name)

  # The site's topsoil available water capacity (cm/cm) from its SSURGO record (fetch.rb ssurgo_erosion).
  def awc
    @awc ||= begin
      need!("ssurgo_erosion.json")
      header, *rows = JSON.parse(File.read(path("ssurgo_erosion.json")))["Table"]
      top = rows.map { |r| header.zip(r).to_h }.min_by { |r| r["hzdept_r"].to_i }
      Float(top.fetch("awc_r"))
    end
  end

  # { year => bu/acre } from the site's NASS county yields, the first series in sites.yml with 15+ years,
  # and that series' short_desc; [{}, nil] when NASS has not been fetched.
  def nass_yields(crop)
    return [{}, nil] unless File.exist?(path("nass/yield_county.json"))

    rows = JSON.parse(File.read(path("nass/yield_county.json")))
    SITE.dig("yield_desc", crop).to_a.each do |desc|
      series = rows.select { |r| r["short_desc"] == desc && r["reference_period_desc"] == "YEAR" }
                   .filter_map { |r| (v = Float(r["Value"].to_s.delete(","), exception: false)) && [r["year"].to_i, v] }.to_h
      return [series, desc] if series.size >= 15
    end
    [{}, nil]
  end

  def need!(*names)
    missing = names.reject { |n| File.exist?(path(n)) }
    raise Blocked, "missing #{missing.join(', ')} (run fetch.rb)" if missing.any?
  end

  def manifest = File.exist?(path("manifest.json")) ? JSON.parse(File.read(path("manifest.json"))) : {}

  # ---------------------------------------------------------------- readers

  # { Date => { tmax:, tmin:, tmean:, rain:, rh:, ws:, rs:, gwet:, tdew: } }, nil where POWER has -999.
  def power_daily
    @power_daily ||= begin
      need!("power_daily.json")
      body = JSON.parse(File.read(path("power_daily.json")))
      @elevation = body.dig("geometry", "coordinates", 2)
      p = body.dig("properties", "parameter")
      map = { tmax: "T2M_MAX", tmin: "T2M_MIN", tmean: "T2M", rain: "PRECTOTCORR", rh: "RH2M", ws: "WS2M",
              rs: "ALLSKY_SFC_SW_DWN", gwet: "GWETROOT", tdew: "T2MDEW" }
      p["T2M"].keys.to_h do |k|
        [ Date.strptime(k, "%Y%m%d"), map.transform_values { |param| (v = p.dig(param, k)) && v > -999 ? v : nil } ]
      end
    end
  end

  def elevation
    power_daily
    @elevation
  end

  # { Date => mm } from GPM IMERG through POWER (UTC days).
  def imerg
    @imerg ||= begin
      need!("imerg_daily.json")
      JSON.parse(File.read(path("imerg_daily.json"))).dig("properties", "parameter", "IMERG_PRECTOT")
          .filter_map { |k, v| [ Date.strptime(k, "%Y%m%d"), v ] if v && v > -999 }.to_h
    end
  end

  # { Date => { tmax:, tmin:, rain: } } from Daymet (1 km, station-interpolated).
  def daymet
    @daymet ||= begin
      need!("daymet.csv")
      lines = File.readlines(path("daymet.csv"))
      start = lines.index { |l| l.start_with?("year,") }
      CSV.parse(lines[start..].join, headers: true).to_h do |r|
        [ Date.ordinal(r["year"].to_i, r["yday"].to_i), { tmax: r["tmax (deg c)"].to_f, tmin: r["tmin (deg c)"].to_f, rain: r["prcp (mm/day)"].to_f } ]
      end
    end
  end

  # RMA cause-of-loss rows for Iowa (30 pipe-delimited fields), as hashes.
  RMA_FIELDS = %i[year state_code state county_code county commodity_code commodity plan_code plan coverage stage
                  cause_code cause month_code month loss_year policies_earning policies_indemnified net_planted
                  endorsed_acres liability total_premium producer_premium subsidy f25 f26 f27 determined_acres
                  indemnity loss_ratio].freeze
  def rma(year)
    file = path("rma/colsom_#{year}_#{SITE['state_alpha']}.txt")
    return [] unless File.exist?(file)

    File.foreach(file).map do |line|
      v = line.chomp.split("|").map(&:strip)
      row = RMA_FIELDS.zip(v).to_h
      %i[liability indemnity determined_acres net_planted].each { |k| row[k] = row[k].to_f }
      row
    end
  end

  # ---------------------------------------------------------------- FAO-56

  def ra(lat, doy)
    phi = lat * Math::PI / 180
    dr = 1 + (0.033 * Math.cos(2 * Math::PI * doy / 365))
    dec = 0.409 * Math.sin((2 * Math::PI * doy / 365) - 1.39)
    ws = Math.acos((-Math.tan(phi) * Math.tan(dec)).clamp(-1, 1))
    (24 * 60 / Math::PI) * GSC * dr * ((ws * Math.sin(phi) * Math.sin(dec)) + (Math.cos(phi) * Math.cos(dec) * Math.sin(ws)))
  end

  def e0(t) = 0.6108 * Math.exp(17.27 * t / (t + 237.3))

  # Daily FAO-56 Eq. 6 with the day's own wind (WS2M) unless u2 is given.
  def et0(day, v, u2: nil)
    u2 ||= v[:ws] || 2.0
    pressure = 101.3 * (((293 - (0.0065 * elevation)) / 293)**5.26)
    gamma = 0.000665 * pressure
    tmax, tmin, rh, rs = v.values_at(:tmax, :tmin, :rh, :rs)
    return nil if [ tmax, tmin, rh, rs ].any?(&:nil?)

    t = (tmax + tmin) / 2
    es = (e0(tmax) + e0(tmin)) / 2
    ea = es * rh / 100
    delta = 4098 * e0(t) / ((t + 237.3)**2)
    rso = (0.75 + (2e-5 * elevation)) * ra(LAT, day.yday)
    rnl = SIGMA * (((tmax + 273.16)**4 + (tmin + 273.16)**4) / 2) * (0.34 - (0.14 * Math.sqrt(ea))) * ((1.35 * [ rs / rso, 1.0 ].min) - 0.35)
    rn = ((1 - ALBEDO) * rs) - rnl
    [ ((0.408 * delta * rn) + (gamma * (900 / (t + 273)) * u2 * (es - ea))) / (delta + (gamma * (1 + (0.34 * u2)))), 0 ].max
  end

  def et0_series(u2: nil) = power_daily.to_h { |day, v| [ day, et0(day, v, u2: u2) ] }

  def kc(day, (k_ini, k_mid, k_end), (ini, dev, mid, late))
    return k_ini if day < ini
    return k_ini + ((k_mid - k_ini) * (day - ini) / dev.to_f) if day < ini + dev
    return k_mid if day < ini + dev + mid

    k_mid + ((k_end - k_mid) * (day - ini - dev - mid) / late.to_f)
  end

  def effective_rain(mm) = mm > 75 ? (0.8 * mm) - 25 : [ (0.6 * mm) - 10, 0 ].max

  # Crops::WaterNeed on one real season: ETc, effective rain and the month-by-month deficit (mm).
  def season_need(key, year, et0s, rain, planting: nil, planting_day: 1)
    fao = AGRONOMY.dig(key, "fao56")
    start = Date.new(year, planting || fao["planting_month"], planting_day)
    crop = Hash.new(0.0)
    rn = Hash.new(0.0)
    cnt = Hash.new(0)
    fao["stages"].sum.times do |i|
      day = start + i
      e = et0s[day] or return nil
      crop[day.month] += kc(i, fao["kc"], fao["stages"]) * e
      rn[day.month] += rain[day].to_f
      cnt[day.month] += 1
    end
    eff = rn.to_h { |m, mm| dim = Date.new(year, m, -1).day; [ m, effective_rain(mm * dim / cnt[m]) * cnt[m] / dim ] }
    { crop_mm: crop.values.sum, rain_mm: rn.values.sum, effective_mm: eff.values.sum,
      deficit_mm: crop.sum { |m, mm| [ mm - eff[m], 0 ].max }, from: start, to: start + fao["stages"].sum - 1 }
  end

  # FAO-56 soil buffer (RAW) then FAO-33: Ya/Ym = 1 - Ky (1 - ETa/ETc).
  def yield_factor(key, need, zr: ZR.fetch(key))
    raw = P.fetch(key) * 1000 * awc * zr
    stress = [ need[:deficit_mm] - raw, 0 ].max
    (1 - (KY.fetch(key) * (stress / need[:crop_mm]))).clamp(0, 1)
  end

  # ---------------------------------------------------------------- statistics

  def mean(a) = a.sum.to_f / a.size

  def pearson(x, y)
    mx = mean(x)
    my = mean(y)
    cov = x.zip(y).sum { |a, b| (a - mx) * (b - my) }
    sx = Math.sqrt(x.sum { |a| (a - mx)**2 })
    sy = Math.sqrt(y.sum { |b| (b - my)**2 })
    sx.zero? || sy.zero? ? nil : cov / (sx * sy)
  end

  def ranks(a)
    sorted = a.each_with_index.sort_by(&:first)
    r = Array.new(a.size)
    sorted.chunk_while { |(v1, _), (v2, _)| v1 == v2 }.reduce(0) do |pos, group|
      avg = pos + ((group.size + 1) / 2.0)
      group.each { |(_, i)| r[i] = avg }
      pos + group.size
    end
    r
  end

  def spearman(x, y) = pearson(ranks(x), ranks(y))

  # Two-sided p-value of a correlation by permutation (no distribution assumed).
  def permutation_p(x, y, stat: :pearson, n: 5000, seed: 42)
    observed = send(stat, x, y).abs
    rng = Random.new(seed)
    hits = n.times.count { (send(stat, x, y.shuffle(random: rng)) || 0).abs >= observed }
    (hits + 1).to_f / (n + 1)
  end

  def rmse(a, b) = Math.sqrt(mean(a.zip(b).map { |x, y| (x - y)**2 }))
  def bias(a, b) = mean(a.zip(b).map { |x, y| x - y })

  # Least-squares line through (x, y): [intercept, slope].
  def linear_fit(x, y)
    mx = mean(x)
    my = mean(y)
    slope = x.zip(y).sum { |a, b| (a - mx) * (b - my) } / x.sum { |a| (a - mx)**2 }
    [ my - (slope * mx), slope ]
  end

  # ---------------------------------------------------------------- results

  def verdict(pass) = pass.nil? ? "BLOCKED" : (pass ? "PASS" : "FAIL")

  # Merges one study's result into validation_out.json and prints its verdict line.
  def record(study, question:, truth:, criterion:, verdict:, summary:, details: {})
    all = File.exist?(OUT) ? JSON.parse(File.read(OUT)) : {}
    all[study] = { question: question, truth: truth, criterion: criterion, verdict: verdict, summary: summary,
                   details: details, run_at: Time.now.utc.iso8601 }
    File.write(OUT, JSON.pretty_generate(all))
    puts "\n#{study}: #{verdict}  #{summary}"
  end

  def heading(text) = puts("\n== #{text} ==")
end
