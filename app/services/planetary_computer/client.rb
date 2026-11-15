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
    MAX_SCENES = 8
    PER_MONTH = 4 # least cloudy scenes tried per month before giving up on it
    THREADS = 4   # months asked in parallel (the point API is slow per request)

    attr_reader :last_error

    def initialize(cache: Rails.cache)
      @cache = cache
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
            client = self.class.new(cache: @cache) # one client per thread: its own connections and last_error
            while (i = (queue.pop(true) rescue nil))
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

    def stac = @stac ||= build(STAC_URL)
    def data = @data ||= build(DATA_URL)

    def build(url)
      Faraday.new(url: url, headers: { "Content-Type" => "application/json" }) do |f|
        f.response :json, content_type: /\bjson$/
        f.request :retry, max: 2, interval: 0.5, retry_statuses: [ 429, 502, 503, 504 ], methods: %i[get post]
        f.adapter Faraday.default_adapter
        f.options.timeout = 20
        f.options.open_timeout = 5
      end
    end
  end
end
