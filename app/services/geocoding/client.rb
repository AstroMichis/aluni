module Geocoding
  # Place search and reverse geocoding for the field finder, through OpenStreetMap's
  # Nominatim. One class so the provider can be swapped later. The usage policy is
  # kept here: an identifying User-Agent, searches only on submit (the finder), a
  # per-IP throttle (Rack::Attack "places/ip"), a 24 h cache, no retry on a 429
  # (one request per second overall), and reverse lookups at zoom 10 with the
  # coordinates rounded to three decimals (about 100 m; a town, never the exact pin).
  #
  # Every failure path returns nil and leaves the reason in #last_error
  # ({ type: :paused | :rate_limited | :api_error | :network_error | :not_found | :unexpected }).
  # Platform::ServicePaused is rescued HERE, not left to the controller: the finder
  # loads these answers into Turbo Frames, which cannot follow a redirect.
  class Client
    BASE_URL = "https://nominatim.openstreetmap.org"
    USER_AGENT = "Aluni/1.0 (+https://aluni.us)"
    CACHE_PREFIX = "geocode/v1"
    CACHE_TTL = 24.hours
    SEARCH_LIMIT = 5
    REVERSE_ZOOM = 10
    QUERY_MAX = 200
    LABEL_MAX = 200
    SHORT_MAX = 100
    # Which address part names the region, in order of preference.
    ADMIN_KEYS = %w[state province region county state_district].freeze
    PLACE_KEYS = %w[city town village hamlet municipality suburb county].freeze

    attr_reader :last_error

    def initialize
      @last_error = nil
    end

    # Up to five places for a typed town or address: an Array of normalised rows,
    # [] for a blank query, nil on failure.
    def search(query, locale: I18n.locale)
      @last_error = nil
      text = query.to_s.squish.first(QUERY_MAX)
      return [] if text.blank?

      cached("search/#{locale}/#{text.downcase}") do
        rows = request("/search", q: text, format: "jsonv2", limit: SEARCH_LIMIT, addressdetails: 1, "accept-language": locale)
        next nil if rows.nil?
        next unexpected unless rows.is_a?(Array)

        rows.filter_map { |row| normalize(row) }
      end
    end

    # The place around a pin: one normalised row, nil when nothing is there
    # (open sea: last_error type :not_found) or on failure.
    def reverse(latitude:, longitude:, locale: I18n.locale)
      @last_error = nil
      lat = latitude.to_f.round(3)
      lon = longitude.to_f.round(3)

      cached("reverse/#{locale}/#{lat}/#{lon}") do
        row = request("/reverse", lat: lat, lon: lon, format: "jsonv2", zoom: REVERSE_ZOOM, addressdetails: 1, "accept-language": locale)
        next nil if row.nil?
        next unexpected unless row.is_a?(Hash)
        next not_found if row["error"].present?

        normalize(row) || not_found
      end
    end

    private

    # Failures are never cached (skip_nil), so the next request tries again.
    def cached(key, &block)
      Rails.cache.fetch("#{CACHE_PREFIX}/#{key}", expires_in: CACHE_TTL, skip_nil: true, &block)
    end

    def request(path, params)
      Platform::Switchboard.guard!(:geocoding)
      response = connection.get(path, params)
      return response.body if response.success?

      @last_error = { type: response.status == 429 ? :rate_limited : :api_error, status: response.status }
      Rails.logger.warn("[Geocoding::Client] #{path} answered #{response.status}")
      nil
    rescue Platform::ServicePaused
      @last_error = { type: :paused }
      nil
    rescue Faraday::Error => e
      @last_error = { type: :network_error, message: e.message }
      Rails.logger.warn("[Geocoding::Client] #{path} failed: #{e.class}: #{e.message}")
      nil
    end

    def not_found
      @last_error = { type: :not_found }
      nil
    end

    def unexpected
      @last_error = { type: :unexpected }
      nil
    end

    # One Nominatim row (jsonv2 with addressdetails) into the shape the finder uses.
    def normalize(row)
      return nil unless row.is_a?(Hash)

      lat = Float(row["lat"].to_s, exception: false)
      lon = Float(row["lon"].to_s, exception: false)
      return nil unless lat&.between?(-90, 90) && lon&.between?(-180, 180)

      address = row["address"].is_a?(Hash) ? row["address"] : {}
      country_code = address["country_code"].to_s.strip.upcase
      country_code = nil unless country_code.match?(/\A[A-Z]{2}\z/)
      admin_area = ADMIN_KEYS.filter_map { |key| address[key].presence }.first&.first(SHORT_MAX)
      label = row["display_name"].to_s.squish.first(LABEL_MAX)
      name = row["name"].presence || PLACE_KEYS.filter_map { |key| address[key].presence }.first || label.split(",").first.to_s.strip
      display = [ name, admin_area ].compact.map(&:strip).reject(&:empty?).uniq.join(", ").first(SHORT_MAX)

      {
        label: label, display: display.presence || label.first(SHORT_MAX),
        latitude: lat.round(6), longitude: lon.round(6),
        country_code: country_code, country: address["country"].presence&.first(SHORT_MAX), admin_area: admin_area
      }
    end

    # Retries once on a dropped connection or a timeout only; a 429 is never
    # retried (Nominatim's one request per second policy).
    def connection
      @connection ||= Faraday.new(url: BASE_URL, headers: { "User-Agent" => USER_AGENT, "Accept" => "application/json" }) do |f|
        f.request :retry, max: 1, interval: 0.5, methods: [ :get ], retry_statuses: [],
                          exceptions: [ Faraday::ConnectionFailed, Faraday::TimeoutError ]
        f.response :json, content_type: /\bjson\z/
        f.adapter Faraday.default_adapter
        f.options.timeout = 8
        f.options.open_timeout = 4
      end
    end
  end
end
