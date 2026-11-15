module PlanetaryComputer
  # Landsat Collection 2 (NASA/USGS) and Sentinel-2 L2A (ESA) from Microsoft
  # Planetary Computer, no account or key. STAC search finds scenes over a
  # point; the data API (TiTiler) computes values at that point server side, so
  # no imagery is downloaded. Every failure returns nil and leaves the reason
  # in #last_error.
  class Client
    STAC_URL = "https://planetarycomputer.microsoft.com/api/stac/v1/".freeze
    DATA_URL = "https://planetarycomputer.microsoft.com/api/data/v1/".freeze
    COLLECTION = "sentinel-2-l2a".freeze
    LANDSAT = "landsat-c2-l2".freeze
    NDVI = "(B08_b1-B04_b1)/(B08_b1+B04_b1)".freeze
    LANDSAT_NDVI = "(nir08_b1-red_b1)/(nir08_b1+red_b1)".freeze
    # Sentinel-2 scene classification (SCL) classes that are a clear view of the
    # ground: 4 vegetation, 5 not vegetated (bare soil), 6 water.
    CLEAR_SCL = [ 4, 5, 6 ].freeze
    # Landsat QA_PIXEL: bit 6 clear; bits 1-4 dilated cloud, cirrus, cloud, cloud shadow.
    LANDSAT_CLEAR_BIT = 1 << 6
    LANDSAT_CLOUD_BITS = 0b11110
    # Per collection: the NDVI band math, the per-pixel quality band and its test.
    MISSIONS = {
      COLLECTION => { mission: "sentinel-2", ndvi: NDVI, quality: "SCL_b1", clear: ->(v) { CLEAR_SCL.include?(v.round) } },
      LANDSAT => { mission: "landsat", ndvi: LANDSAT_NDVI, quality: "qa_pixel_b1",
                   clear: ->(v) { (v.to_i & LANDSAT_CLEAR_BIT).positive? && (v.to_i & LANDSAT_CLOUD_BITS).zero? } }
    }.freeze
    NASADEM = "nasadem".freeze
    NASADEM_BAND = "elevation_b1".freeze
    NASADEM_LATITUDES = [ -56, 60 ].freeze # the shuttle's radar swath
    NASADEM_VOID = -500                    # voids are -32768; the lowest land is about -430 m
    # Three NASADEM pixels to each side: whole metres and radar noise make a
    # one-pixel slope swing by several percent (6 % on a 1 % Nebraska field);
    # at 90 m it lands within about 1 % of the 3DEP lidar.
    TERRAIN_STEP_M = 90.0
    MAX_SCENES = 8
    PER_MONTH = 4 # least cloudy scenes tried per month before giving up on it
    THREADS = 2   # months asked in parallel: more trips the API's burst limit (429)
    # Retries for 429 and 5xx: exponential backoff with jitter (about 2, 4, 8, 16 s),
    # or the server's Retry-After when it sends one.
    RETRY = { max: 4, interval: 2, backoff_factor: 2, interval_randomness: 0.5, max_interval: 30,
              retry_statuses: [ 429, 502, 503, 504 ], methods: %i[get post] }.freeze

    attr_reader :last_error

    def initialize(cache: Rails.cache, retry_options: RETRY)
      @cache = cache
      @retry_options = retry_options
      @last_error = nil
    end

    # Scenes over the point, least cloudy first:
    # [{ id:, collection:, datetime: Time, cloud_cover: Float }, ...] or nil.
    def scenes(lat:, lon:, from:, to:, max_cloud: 30, limit: MAX_SCENES, collections: [ COLLECTION ])
      @last_error = nil
      body = {
        collections: collections,
        intersects: { type: "Point", coordinates: [ lon.to_f, lat.to_f ] },
        datetime: "#{from.to_date.iso8601}T00:00:00Z/#{to.to_date.iso8601}T23:59:59Z",
        query: { "eo:cloud_cover" => { "lt" => max_cloud } },
        sortby: [ { field: "properties.eo:cloud_cover", direction: "asc" } ],
        limit: limit
      }
      response = request { stac.post("search", body.to_json) }
      return unless response

      Array(response.body["features"]).map do |feature|
        props = feature["properties"] || {}
        { id: feature["id"], collection: feature["collection"] || collections.first,
          datetime: Time.iso8601(props["datetime"]), cloud_cover: props["eo:cloud_cover"].to_f }
      end
    rescue ArgumentError => e
      failure(:empty_response, "unreadable scene date: #{e.message}")
    end

    # One value at the point for a band expression on one scene, or nil.
    # unscale applies the collection's scale and offset (surface reflectance).
    def point_value(lat:, lon:, item:, expression:, collection: COLLECTION, unscale: false)
      @last_error = nil
      path = "item/point/#{lon.to_f},#{lat.to_f}"
      params = { collection: collection, item: item, expression: expression, asset_as_band: false }
      params[:unscale] = true if unscale
      response = request { data.get(path, params) }
      return unless response

      value = Array(response.body["values"]).first
      value.nil? ? failure(:empty_response, "no value at the point") : value.to_f
    end

    # Elevation and slope at the point from NASADEM (NASA's reprocessed SRTM,
    # 1 arc-second, about 30 m, 56°S to 60°N), the same four-neighbour slope
    # as Usgs::ElevationClient but 90 m out: { "elevation" => 74.0, "slope" => 3.2 }
    # (metres, percent), {} outside the coverage, or nil when a call fails.
    def terrain(lat:, lon:)
      @last_error = nil
      lat = lat.to_f
      lon = lon.to_f
      return {} unless lat.between?(*NASADEM_LATITUDES)

      key = [ "planetary_computer/nasadem/v1", lat.round(5), lon.round(5) ].join("/")
      cached = @cache.read(key)
      return cached if cached

      dlat = TERRAIN_STEP_M / 111_320
      dlon = TERRAIN_STEP_M / (111_320 * Math.cos(lat * Math::PI / 180))
      points = { center: [ lat, lon ], east: [ lat, lon + dlon ], west: [ lat, lon - dlon ],
                 north: [ lat + dlat, lon ], south: [ lat - dlat, lon ] }
      z = {}
      points.each do |name, (plat, plon)|
        z[name] = nasadem_elevation(plat, plon)
        return z[name] if z[name].nil? || z[name] == {} # failed, or no land in the tile
      end

      dzdx = (z[:east] - z[:west]) / (2 * TERRAIN_STEP_M)
      dzdy = (z[:north] - z[:south]) / (2 * TERRAIN_STEP_M)
      result = { "elevation" => z[:center].round(1), "slope" => (100 * Math.hypot(dzdx, dzdy)).round(1) }
      @cache.write(key, result, expires_in: 30.days) # the DEM is from 2000; it does not change
      result
    end

    # NDVI time series at the point from clear-sky Sentinel-2 pixels, newest
    # first: [{ date: Date, ndvi: Float, scene: String, cloud_cover: Float }, ...]
    # or nil. Scenes cloudy at the pixel (per SCL) are skipped.
    def ndvi(lat:, lon:, from:, to:, max_cloud: 30)
      @last_error = nil
      key = [ "planetary_computer/ndvi/v1", lat.to_f.round(4), lon.to_f.round(4), from.to_date, to.to_date, max_cloud ].join("/")
      cached = @cache.read(key)
      return cached if cached

      found = scenes(lat: lat, lon: lon, from: from, to: to, max_cloud: max_cloud)
      return unless found

      series = found.filter_map do |scene|
        reading = clear_ndvi(lat, lon, scene)
        reading && { date: scene[:datetime].to_date, ndvi: reading.round(3), scene: scene[:id], cloud_cover: scene[:cloud_cover] }
      end
      series = series.sort_by { |row| row[:date] }.reverse
      @last_error = nil
      @cache.write(key, series, expires_in: 6.hours)
      series
    end

    # One clear-sky NDVI per calendar month over the last `months` months,
    # from Landsat and Sentinel-2 together (the least cloudy scene whose pixel
    # is clear), oldest first. A month with no clear view keeps ndvi nil.
    # [{ "month" => "2025-08", "ndvi" => 0.64, "date" => "2025-08-14",
    #    "mission" => "sentinel-2", "scene" => "S2B_..." }, ...] or nil when
    # the search itself fails.
    def monthly_ndvi(lat:, lon:, months: 12, today: Date.current, max_cloud: 50, threads: THREADS)
      @last_error = nil
      first = today.beginning_of_month << (months - 1)
      queue = Queue.new
      (0...months).each { |i| queue << i }
      rows = Array.new(months)
      failed = nil
      workers = Array.new([ threads, months ].min) do
        Thread.new do
          # The executor checks a database connection out and back for the switchboard guard.
          Rails.application.executor.wrap do
            client = self.class.new(cache: @cache, retry_options: @retry_options) # one client per thread: its own connections and last_error
            # A failed month stops the others: retrying a rate limit at full speed makes it worse.
            while !failed && (i = (queue.pop(true) rescue nil))
              rows[i] = client.send(:month_row, lat, lon, first >> i, today, max_cloud)
              failed ||= client.last_error if rows[i].nil?
            end
          end
        end
      end
      workers.each(&:join)
      return failure(failed[:type], failed[:message], status: failed[:status]) if failed

      rows
    end

    def rate_limited? = last_error&.dig(:type) == :rate_limited

    private

    # The month's row for #monthly_ndvi, or nil when its search fails.
    def month_row(lat, lon, month, today, max_cloud)
      found = scenes(lat: lat, lon: lon, from: month, to: [ month.end_of_month, today ].min, max_cloud: max_cloud,
                     limit: PER_MONTH, collections: [ LANDSAT, COLLECTION ])
      return if found.nil?

      row = { "month" => month.strftime("%Y-%m"), "ndvi" => nil }
      pick = found.lazy.filter_map { |scene| (v = clear_ndvi(lat, lon, scene)) && [ scene, v ] }.first
      return row unless pick

      scene, value = pick
      row.merge("ndvi" => value.round(3), "date" => scene[:datetime].to_date.iso8601,
                "mission" => MISSIONS.dig(scene[:collection], :mission), "scene" => scene[:id])
    end

    # NDVI at the point when the pixel is clear in the scene's quality band, else nil.
    def clear_ndvi(lat, lon, scene)
      mission = MISSIONS.fetch(scene[:collection] || COLLECTION)
      quality = point_value(lat: lat, lon: lon, item: scene[:id], expression: mission[:quality], collection: scene[:collection] || COLLECTION)
      return unless quality && mission[:clear].call(quality)

      value = point_value(lat: lat, lon: lon, item: scene[:id], expression: mission[:ndvi],
                          collection: scene[:collection] || COLLECTION, unscale: true)
      value&.finite? && value.between?(-1, 1) ? value : nil
    end

    def request
      Platform::Switchboard.guard!(:planetary_computer)
      response = yield
      return response if response.success?

      failure(response.status == 429 ? :rate_limited : :api_error, response.body.to_s[0, 500], status: response.status)
    rescue Faraday::Error => e
      failure(:network_error, e.message)
    end

    def failure(type, message, status: nil)
      @last_error = { type: type, status: status, message: message }
      Rails.logger.warn("Planetary Computer error: type=#{type} status=#{status} message=#{message}")
      nil
    end

    # Metres at the point from the 1°x1° NASADEM tile holding it (the item id
    # is its south-west corner, NASADEM_HGT_s42w073), {} when there is no tile
    # (open sea) or the pixel is void, nil when the call fails.
    def nasadem_elevation(lat, lon)
      south = lat.floor
      west = lon.floor
      item = format("NASADEM_HGT_%s%02d%s%03d", south.negative? ? "s" : "n", south.abs, west.negative? ? "w" : "e", west.abs)
      Platform::Switchboard.guard!(:planetary_computer)
      response = data.get("item/point/#{lon},#{lat}", collection: NASADEM, item: item, expression: NASADEM_BAND, asset_as_band: false)
      return {} if response.status == 404
      return failure(response.status == 429 ? :rate_limited : :api_error, response.body.to_s[0, 500], status: response.status) unless response.success?

      value = Array(response.body["values"]).first
      value.nil? || value.to_f < NASADEM_VOID ? {} : value.to_f
    rescue Faraday::Error => e
      failure(:network_error, e.message)
    end

    def stac = @stac ||= build(STAC_URL)
    def data = @data ||= build(DATA_URL)

    def build(url)
      Faraday.new(url: url, headers: { "Content-Type" => "application/json" }) do |f|
        f.response :json, content_type: /\bjson$/
        f.request :retry, **@retry_options
        f.adapter Faraday.default_adapter
        f.options.timeout = 20
        f.options.open_timeout = 5
      end
    end
  end
end
