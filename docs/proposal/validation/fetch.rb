# frozen_string_literal: true

# Fetches the public records the hindcast (docs/proposal/validation/v*.rb) scores Aluni against,
# for one field of sites.yml (SITE=ames, the worked example's Ames pin, by default; SITE=york for York, Nebraska).
# Run it once; every analysis afterwards is offline and reproducible.
#
#   mise exec -- bin/rails runner docs/proposal/validation/fetch.rb            # everything still missing (Ames)
#   SITE=york mise exec -- bin/rails runner docs/proposal/validation/fetch.rb  # the York, Nebraska field
#   mise exec -- bin/rails runner docs/proposal/validation/fetch.rb --only=nass,zhao2022 # some sources again
#   mise exec -- bin/rails runner docs/proposal/validation/fetch.rb --list      # what it would fetch
#
# It reuses the app's clients where one exists (NasaPower, Cdl, Gaez, PlanetaryComputer) and reads
# NASS_API_KEY from the environment. No key is written to any file: the manifest records URLs with
# the key removed. A source that fails is logged in the manifest and the others carry on.

require "json"
require "yaml"
require "fileutils"
require "open3"

SITE_KEY = ENV.fetch("SITE", "ames")
SITE = YAML.safe_load_file(File.expand_path("sites.yml", __dir__)).fetch(SITE_KEY) { abort "unknown SITE #{SITE_KEY} (sites.yml)" }
LAT = SITE.fetch("lat")
LON = SITE.fetch("lon")
STATE_ALPHA = SITE.fetch("state_alpha")
STATE_FIPS = SITE.fetch("state_fips")
COUNTY_FIPS = SITE.fetch("county_fips")
FIRST_YEAR = 2001
LAST_YEAR = 2025
GAUGE_KM = 30
DIR = File.expand_path("data/#{SITE_KEY}", __dir__)
MANIFEST = File.join(DIR, "manifest.json")
FileUtils.mkdir_p(DIR)

only = ARGV.find { |a| a.start_with?("--only=") }&.split("=", 2)&.last&.split(",")
list_only = ARGV.include?("--list")
manifest = File.exist?(MANIFEST) ? JSON.parse(File.read(MANIFEST)) : {}

HTTP = Faraday.new do |f|
  f.request :retry, max: 4, interval: 2, backoff_factor: 2, interval_randomness: 0.5,
                    retry_statuses: [ 429, 500, 502, 503, 504 ], methods: %i[get]
  f.response :raise_error
  f.options.open_timeout = 15
  f.options.timeout = 300
end

# Follows redirects (figshare and others answer a download with 302 to the file store); an empty
# body is an error, never a saved file.
def http_get(url, params = {}, hops = 5)
  response = HTTP.get(url, params)
  if (300..399).cover?(response.status) && response.headers["location"]
    raise "too many redirects: #{url}" if hops.zero?

    return http_get(URI.join(url, response.headers["location"]).to_s, {}, hops - 1)
  end
  raise "empty body from #{url}" if response.body.to_s.empty?

  response.body
end

def save(name, body)
  path = File.join(DIR, name)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, body.is_a?(String) ? body : JSON.pretty_generate(body))
  path
end

def km(lat1, lon1, lat2, lon2)
  rad = Math::PI / 180
  a = (Math.sin((lat2 - lat1) * rad / 2)**2) + (Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * (Math.sin((lon2 - lon1) * rad / 2)**2))
  12_742 * Math.asin(Math.sqrt(a))
end

def scrub(text) = text.to_s.gsub(/key=[^&\s"]+/, "key=REDACTED")

POWER = "https://power.larc.nasa.gov/api/temporal/"
power_point = { community: "AG", latitude: LAT, longitude: LON, format: "JSON" }

# Each source: files it writes, and the block that writes them. `done?` skips what is already there.
SOURCES = {
  "power_daily" => {
    files: [ "power_daily.json" ], url: "#{POWER}daily/point",
    run: lambda {
      params = power_point.merge(parameters: "T2M,T2M_MIN,T2M_MAX,PRECTOTCORR,RH2M,WS2M,ALLSKY_SFC_SW_DWN,GWETROOT,T2MDEW",
                                 start: "#{FIRST_YEAR}0101", end: "#{LAST_YEAR}1231")
      save("power_daily.json", http_get("#{POWER}daily/point", params))
    }
  },
  "power_hourly" => {
    files: (FIRST_YEAR..LAST_YEAR).map { |y| "power_hourly/#{y}.json" }, url: "#{POWER}hourly/point",
    run: lambda {
      (FIRST_YEAR..LAST_YEAR).each do |y|
        next if File.exist?(File.join(DIR, "power_hourly/#{y}.json"))

        params = power_point.merge(parameters: "T2M,RH2M,PRECTOTCORR,WS2M", start: "#{y}0501", end: "#{y}0930", "time-standard": "LST")
        save("power_hourly/#{y}.json", http_get("#{POWER}hourly/point", params))
        sleep 1
      end
    }
  },
  "power_climatology" => {
    files: [ "power_climatology.json" ], url: "#{POWER}climatology/point",
    run: -> { save("power_climatology.json", http_get("#{POWER}climatology/point", power_point.merge(parameters: NasaPower::Client::CLIMATOLOGY.join(",")))) }
  },
  "imerg" => {
    files: [ "imerg_daily.json" ], url: "#{POWER}daily/point (IMERG_PRECTOT)",
    run: lambda {
      params = power_point.merge(parameters: "IMERG_PRECTOT", "time-standard": "UTC", start: "#{FIRST_YEAR}0101", end: "#{LAST_YEAR}1231")
      save("imerg_daily.json", http_get("#{POWER}daily/point", params))
    }
  },
  "daymet" => {
    files: [ "daymet.csv" ], url: "https://daymet.ornl.gov/single-pixel/api/data",
    run: lambda {
      save("daymet.csv", http_get("https://daymet.ornl.gov/single-pixel/api/data",
                                  lat: LAT, lon: LON, vars: "tmax,tmin,prcp,srad,vp", start: "#{FIRST_YEAR}-01-01", end: "#{LAST_YEAR}-12-31", format: "csv"))
    }
  },
"cocorahs" => {
  # Gauges within GAUGE_KM of the pin, chosen by their own coordinates (county codes are not county
  # names: "ST" is Scott County, 200 km away). The whole state is asked one month at a time and only
  # the nearby rows are kept.
  files: (2008..LAST_YEAR).map { |y| "cocorahs/#{y}.csv" }, url: "https://data.cocorahs.org/export/exportreports.aspx (State=#{STATE_ALPHA}, within #{GAUGE_KM} km)",
  run: lambda {
    (2008..LAST_YEAR).each do |y|
      next if File.exist?(File.join(DIR, "cocorahs/#{y}.csv"))

      header = nil
      rows = (1..12).flat_map do |m|
        last = Date.new(y, m, -1)
        params = { ReportType: "Daily", dtf: 1, Format: "CSV", State: STATE_ALPHA, ReportDateType: "reportdate",
                   StartDate: "#{m}/1/#{y}", EndDate: "#{m}/#{last.day}/#{y}", TimesInGMT: "False" }
        lines = http_get("https://data.cocorahs.org/export/exportreports.aspx", params).to_s.lines
        header ||= lines.first
        sleep 1
        lines.drop(1).select do |line|
          lat, lon = line.split(",")[5, 2].map { |v| Float(v.strip, exception: false) }
          lat && lon && km(lat, lon, LAT, LON) <= GAUGE_KM
        end
      end
      raise "no CoCoRaHS gauge within #{GAUGE_KM} km in #{y}" if rows.empty? && y >= 2010

      save("cocorahs/#{y}.csv", [ header, *rows ].compact.join)
    end
  }
},
  "rma" => {
    # One ZIP per crop year; only Iowa rows are kept (the whole country is about 45 MB a year).
    files: (FIRST_YEAR..LAST_YEAR).map { |y| "rma/colsom_#{y}_#{STATE_ALPHA}.txt" },
    url: "https://pubfs-rma.fpac.usda.gov/pub/Web_Data_Files/Summary_of_Business/cause_of_loss/colsom_{year}.zip",
    run: lambda {
      (FIRST_YEAR..LAST_YEAR).each do |y|
        out = File.join(DIR, "rma/colsom_#{y}_#{STATE_ALPHA}.txt")
        next if File.exist?(out)

        zip = File.join(DIR, "rma/colsom_#{y}.zip")
        FileUtils.mkdir_p(File.dirname(zip))
        File.binwrite(zip, http_get("https://pubfs-rma.fpac.usda.gov/pub/Web_Data_Files/Summary_of_Business/cause_of_loss/colsom_#{y}.zip"))
        text, status = Open3.capture2("unzip", "-p", zip)
        raise "unzip failed for #{y}" unless status.success?

        rows = text.encode("UTF-8", invalid: :replace, undef: :replace).lines.select { |l| l.split("|", 3)[1].to_s.strip == STATE_FIPS }
        File.write(out, rows.join)
        File.delete(zip)
      end
    }
  },
  "cdl" => {
    files: [ "cdl.json" ], url: "Cdl::Client#history",
    run: -> { save("cdl.json", Cdl::Client.new.history(latitude: LAT, longitude: LON, years: (2008..LAST_YEAR).to_a)) }
  },
  "ssurgo_erosion" => {
    # RUSLE inputs for V6: K factor of the surface horizon, the component's USLE slope length and slope.
    files: [ "ssurgo_erosion.json" ], url: "https://sdmdataaccess.sc.egov.usda.gov/Tabular/post.rest",
    run: lambda {
      sql = <<~SQL
        SELECT mu.muname, c.compname, c.comppct_r, c.slope_r, c.slopelenusle_r, c.tfact, h.hzdept_r, h.hzdepb_r, h.kwfact, h.kffact, h.awc_r, h.om_r
        FROM SDA_Get_Mukey_from_intersection_with_WktWgs84('point(#{LON} #{LAT})') k
        JOIN mapunit mu ON mu.mukey = k.mukey
        JOIN component c ON c.mukey = mu.mukey AND c.majcompflag = 'Yes'
        LEFT JOIN chorizon h ON h.cokey = c.cokey
        ORDER BY c.comppct_r DESC, h.hzdept_r
      SQL
      body = HTTP.post("https://sdmdataaccess.sc.egov.usda.gov/Tabular/post.rest", { query: sql, format: "JSON+COLUMNNAME" }.to_json,
                       "Content-Type" => "application/json").body
      save("ssurgo_erosion.json", JSON.parse(body))
    }
  },
  "gaez" => {
    files: [ "gaez.json" ], url: "Gaez::Client (res05, 1981-2010, rainfed, high and low input)",
    run: lambda {
      client = Gaez::Client.new
      crops = %w[Maize Soybean Wheat Sunflower Sorghum Oat Barley Alfalfa]
      out = %w[High Low].to_h do |level|
        layers = client.layers(crops: crops, input_level: level)
        [ level, layers.to_h do |crop, ids|
          [ crop, { "suitability" => ids["suitability"] && client.value(latitude: LAT, longitude: LON, objectid: ids["suitability"]),
                   "attainable_yield" => ids["yield"] && client.value(latitude: LAT, longitude: LON, objectid: ids["yield"]),
                   "yield_units" => ids["yield_units"] } ]
        end ]
      end
      save("gaez.json", out)
    }
  },
  "zhao2022" => {
    files: [ "zhao2022_data.csv" ], url: "https://api.figshare.com/v2/articles/20290923",
    run: lambda {
      meta = JSON.parse(http_get("https://api.figshare.com/v2/articles/20290923"))
      file = meta.fetch("files").find { |f| f["name"] == "data.csv" } or raise "data.csv not in figshare 20290923"
      save("zhao2022_data.csv", http_get(file.fetch("download_url")))
    }
  },
  "ndvi" => {
    # One clear-sky NDVI per month (Landsat + Sentinel-2), the app's own method; 2013 is Landsat 8's first year.
    files: (2013..LAST_YEAR).map { |y| "ndvi/#{y}.json" }, url: "PlanetaryComputer::Client#monthly_ndvi",
    run: lambda {
      client = PlanetaryComputer::Client.new(cache: ActiveSupport::Cache::NullStore.new)
      (2013..LAST_YEAR).each do |y|
        next if File.exist?(File.join(DIR, "ndvi/#{y}.json"))

        rows = client.monthly_ndvi(lat: LAT, lon: LON, months: 12, today: Date.new(y, 12, 31), max_cloud: 60)
        raise "Planetary Computer failed for #{y}: #{client.last_error.inspect}" if rows.nil? || client.last_error

        save("ndvi/#{y}.json", rows)
        sleep 5
      end
    }
  },
  "nass_progress_all" => {
    # Every state's weekly planting progress for the catalog crops NASS tracks, for
    # calendars.rb (config/crops/planting_calendars.yml, read by Crops::PlantingCalendar).
    files: [ "nass/progress_all.json" ], url: "https://quickstats.nass.usda.gov/api/api_GET/ (PCT PLANTED, all states)",
    run: lambda {
      creds = Rails.application.credentials
      key = [ ENV["NASS_API_KEY"], creds.dig(:nass, :api_key), creds.dig(:nass, :key), creds[:nass_api_key], creds[:NASS_API_KEY] ].find(&:present?)
      raise "no NASS key in ENV NASS_API_KEY or credentials" unless key

      commodities = [ "CORN", "SOYBEANS", "SORGHUM", "SUNFLOWER", "OATS", "BARLEY", "WHEAT", "COTTON", "PEANUTS", "RICE", "SUGARBEETS", "DRY EDIBLE BEANS", "POTATOES" ]
      rows = commodities.flat_map do |commodity|
        params = { key: key, source_desc: "SURVEY", statisticcat_desc: "PROGRESS", agg_level_desc: "STATE", unit_desc: "PCT PLANTED",
                   commodity_desc: commodity, year__GE: LAST_YEAR - 11, format: "JSON" }
        JSON.parse(http_get("https://quickstats.nass.usda.gov/api/api_GET/", params)).fetch("data", [])
      rescue StandardError => e
        raise unless e.message.include?("400") # NASS answers 400 when a commodity has no rows
        []
      end
      save("nass/progress_all.json", rows)
    }
  },
  "nass" => {
    files: %w[nass/yield_county.json nass/yield_state.json nass/price_received.json nass/days_suitable.json nass/progress.json],
    url: "https://quickstats.nass.usda.gov/api/api_GET/",
    run: lambda {
      # The environment first, then Rails credentials under the names a key is usually given
      # (as config/initializers/meteomatics.rb does). Only where it came from is printed.
      creds = Rails.application.credentials
      found = { "ENV NASS_API_KEY" => ENV["NASS_API_KEY"], "credentials nass.api_key" => creds.dig(:nass, :api_key),
                "credentials nass.key" => creds.dig(:nass, :key), "credentials nass_api_key" => creds[:nass_api_key],
                "credentials NASS_API_KEY" => creds[:NASS_API_KEY] }.find { |_, v| v.present? }
      raise "no NASS key in ENV NASS_API_KEY or credentials (nass.api_key, nass.key, nass_api_key, NASS_API_KEY)" unless found

      print "(key from #{found.first}) "
      key = found.last.to_s

      base = { key: key, source_desc: "SURVEY", state_alpha: STATE_ALPHA, year__GE: FIRST_YEAR - 5, format: "JSON" }
      queries = {
        "yield_county" => base.merge(sector_desc: "CROPS", statisticcat_desc: "YIELD", agg_level_desc: "COUNTY", county_ansi: COUNTY_FIPS),
        "yield_state" => base.merge(sector_desc: "CROPS", statisticcat_desc: "YIELD", agg_level_desc: "STATE", reference_period_desc: "YEAR"),
        "price_received" => base.merge(statisticcat_desc: "PRICE RECEIVED", agg_level_desc: "STATE", freq_desc: "MONTHLY"),
        "days_suitable" => base.merge(commodity_desc: "FIELDWORK", statisticcat_desc: "DAYS SUITABLE", agg_level_desc: "STATE"),
        "progress" => base.merge(statisticcat_desc: "PROGRESS", agg_level_desc: "STATE", unit_desc: "PCT PLANTED")
      }
      queries.each do |name, params|
        rows = %w[CORN SOYBEANS].flat_map do |commodity|
          next [] if name == "days_suitable" && commodity == "SOYBEANS"

          q = name == "days_suitable" ? params : params.merge(commodity_desc: commodity)
          JSON.parse(http_get("https://quickstats.nass.usda.gov/api/api_GET/", q)).fetch("data", [])
        end
        save("nass/#{name}.json", rows)
      end
    }
  }
}.freeze

unknown = Array(only) - SOURCES.keys
abort "unknown source #{unknown.join(', ')}; choose from: #{SOURCES.keys.join(', ')}" if unknown.any?

SOURCES.each do |name, source|
  next if only && !only.include?(name)

  done = source[:files].all? { |f| File.exist?(File.join(DIR, f)) }
  if list_only
    puts "#{done ? 'have' : 'need'}  #{name.ljust(18)} #{source[:url]}"
    next
  end
  if done && !only
    puts "skip  #{name} (already fetched)"
    next
  end

  print "fetch #{name} ... "
  started = Time.now
  begin
    source[:run].call
    manifest[name] = { "status" => "ok", "url" => source[:url], "files" => source[:files], "fetched_at" => Time.now.utc.iso8601, "seconds" => (Time.now - started).round }
    puts "ok (#{(Time.now - started).round} s)"
  rescue StandardError => e
    manifest[name] = { "status" => "failed", "url" => source[:url], "error" => scrub("#{e.class}: #{e.message}")[0, 400], "fetched_at" => Time.now.utc.iso8601 }
    puts "FAILED: #{manifest[name]['error']}"
  end
  File.write(MANIFEST, JSON.pretty_generate(manifest))
end
puts "\nManifest: #{MANIFEST}" unless list_only
