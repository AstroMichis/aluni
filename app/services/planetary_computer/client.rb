module PlanetaryComputer
  # Sentinel-2 L2A from Microsoft Planetary Computer, no account or key.
  # STAC search finds scenes over a point; the data API (TiTiler) computes
  # values at that point server side, so no imagery is downloaded. Every
  # failure returns nil and leaves the reason in #last_error.
  class Client
    STAC_URL = "https://planetarycomputer.microsoft.com/api/stac/v1/".freeze
    DATA_URL = "https://planetarycomputer.microsoft.com/api/data/v1/".freeze
    COLLECTION = "sentinel-2-l2a".freeze
    NDVI = "(B08_b1-B04_b1)/(B08_b1+B04_b1)".freeze
    # Scene classification (SCL) classes that are a clear view of the ground:
    # 4 vegetation, 5 not vegetated (bare soil), 6 water.
    CLEAR_SCL = [ 4, 5, 6 ].freeze
    MAX_SCENES = 8

    attr_reader :last_error

    def initialize(cache: Rails.cache)
      @cache = cache
      @last_error = nil
    end

    # Scenes over the point, least cloudy first:
    # [{ id:, datetime: Time, cloud_cover: Float }, ...] or nil.
    def scenes(lat:, lon:, from:, to:, max_cloud: 30, limit: MAX_SCENES)
      @last_error = nil
      body = {
        collections: [ COLLECTION ],
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
        { id: feature["id"], datetime: Time.iso8601(props["datetime"]), cloud_cover: props["eo:cloud_cover"].to_f }
      end
    rescue ArgumentError => e
      failure(:empty_response, "unreadable scene date: #{e.message}")
    end

    # One value at the point for a band expression on one scene, or nil.
    def point_value(lat:, lon:, item:, expression:)
      @last_error = nil
      path = "item/point/#{lon.to_f},#{lat.to_f}"
      params = { collection: COLLECTION, item: item, expression: expression, asset_as_band: false }
      response = request { data.get(path, params) }
      return unless response

      value = Array(response.body["values"]).first
      value.nil? ? failure(:empty_response, "no value at the point") : value.to_f
    end

    # NDVI time series at the point from clear-sky pixels, newest first:
    # [{ date: Date, ndvi: Float, scene: String, cloud_cover: Float }, ...]
    # or nil. Scenes cloudy at the pixel (per SCL) are skipped.
    def ndvi(lat:, lon:, from:, to:, max_cloud: 30)
      @last_error = nil
      key = [ "planetary_computer/ndvi/v1", lat.to_f.round(4), lon.to_f.round(4), from.to_date, to.to_date, max_cloud ].join("/")
      cached = @cache.read(key)
      return cached if cached

      found = scenes(lat: lat, lon: lon, from: from, to: to, max_cloud: max_cloud)
      return unless found

      series = found.filter_map do |scene|
        scl = point_value(lat: lat, lon: lon, item: scene[:id], expression: "SCL_b1")
        next unless scl && CLEAR_SCL.include?(scl.round)

        value = point_value(lat: lat, lon: lon, item: scene[:id], expression: NDVI)
        next unless value&.finite?

        { date: scene[:datetime].to_date, ndvi: value.round(3), scene: scene[:id], cloud_cover: scene[:cloud_cover] }
      end
      series = series.sort_by { |row| row[:date] }.reverse
      @last_error = nil
      @cache.write(key, series, expires_in: 6.hours)
      series
    end

    private

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
