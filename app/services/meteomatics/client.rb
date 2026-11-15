module Meteomatics
  # Thin client over the Meteomatics Weather API: one point, a time window and
  # up to MAX_PARAMETERS parameters per query. Every failure returns nil and
  # leaves the reason in #last_error, like Gemini::Client.
  #
  # URL shape: /<start>--<end>:<step>/<p1,p2,...>/<lat,lon>/json
  # Auth: HTTP Basic with the account's username and password.
  class Client
    BASE_URL = "https://api.meteomatics.com".freeze
    MAX_PARAMETERS = 10

    # What a field's weather card needs, current conditions and the next days.
    FORECAST_PARAMETERS = %w[
      t_2m:C
      precip_1h:mm
      prob_precip_1h:p
      relative_humidity_2m:p
      dew_point_2m:C
      wind_speed_10m:ms
      wind_gusts_10m_1h:ms
      evapotranspiration_1h:mm
      soil_moisture_index_-15cm:idx
      t_-5cm:C
    ].freeze

    attr_reader :last_error

    def initialize(username: nil, password: nil, cache: Rails.cache)
      config = Rails.configuration.x.meteomatics
      @username = username || config.username
      @password = password || config.password
      @cache = cache
      @last_error = nil
    end

    def self.configured?
      config = Rails.configuration.x.meteomatics
      config.username.present? && config.password.present?
    end

    # Time series for one point. Returns { "t_2m:C" => [[Time, value], ...] }
    # or nil. Times are UTC; hours counts forward from the current hour.
    def forecast(lat:, lon:, hours: 72, step: "PT1H", parameters: FORECAST_PARAMETERS)
      @last_error = nil
      parameters = Array(parameters)
      if parameters.empty? || parameters.size > MAX_PARAMETERS
        return failure(:invalid_request, "between 1 and #{MAX_PARAMETERS} parameters per query")
      end

      start = Time.now.utc.beginning_of_hour
      window = "#{iso(start)}--#{iso(start + hours.to_i.hours)}:#{step}"
      point = "#{lat.to_f.round(4)},#{lon.to_f.round(4)}"
      # Leading slash: a relative path starting "2026-...T12:" would parse as a URI scheme.
      path = "/#{window}/#{parameters.join(",")}/#{point}/json"

      cached(cache_key(lat, lon, hours, step, parameters, start)) { fetch(path) }
    end

    private

    def fetch(path)
      Platform::Switchboard.guard!(:meteomatics)
      return failure(:not_configured, "Meteomatics credentials are not set") unless @username.present? && @password.present?

      response = connection.get(path)
      return failure(classify(response.status), error_message(response), status: response.status) unless response.success?

      parse(response.body)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      failure(:network_error, e.message)
    rescue Faraday::Error => e
      failure(:network_error, e.message)
    end

    def parse(body)
      data = body.is_a?(Hash) ? body["data"] : nil
      return failure(:empty_response, "no data in the response") if data.blank?

      data.each_with_object({}) do |series, out|
        dates = series.dig("coordinates", 0, "dates") || []
        out[series["parameter"]] = dates.map { |d| [ Time.iso8601(d["date"]), d["value"] ] }
      end
    rescue ArgumentError => e
      failure(:empty_response, "unreadable dates: #{e.message}")
    end

    # Successful answers are cached; failures are not, so a fixed outage or a
    # resumed switch takes effect on the next call.
    def cached(key)
      hit = @cache.read(key)
      return hit if hit

      value = yield
      @cache.write(key, value, expires_in: Rails.configuration.x.meteomatics.cache_ttl) if value
      value
    end

    def cache_key(lat, lon, hours, step, parameters, start)
      [ "meteomatics/v1", lat.to_f.round(2), lon.to_f.round(2), hours, step,
        Digest::SHA256.hexdigest(parameters.join(","))[0, 16], start.to_i ].join("/")
    end

    def classify(status)
      case status
      when 401, 403 then :unauthorized
      when 429 then :rate_limited
      when 500..599 then :service_unavailable
      else :api_error
      end
    end

    def error_message(response)
      body = response.body
      (body.is_a?(Hash) ? body["message"] : body).to_s[0, 500]
    end

    def failure(type, message, status: nil)
      @last_error = { type: type, status: status, message: message }
      Rails.logger.warn("Meteomatics error: type=#{type} status=#{status} message=#{message}")
      nil
    end

    def iso(time) = time.utc.strftime("%Y-%m-%dT%H:%M:%SZ")

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :authorization, :basic, @username, @password
        f.response :json, content_type: /\bjson$/
        f.request :retry, max: 2, interval: 0.5, retry_statuses: [ 502, 503, 504 ]
        f.adapter Faraday.default_adapter
        f.options.timeout = 20
        f.options.open_timeout = 5
      end
    end
  end
end
