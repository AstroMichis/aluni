# frozen_string_literal: true

module Appeears
  # NASA AppEEARS (docs/data_sources/appeears.md): values of NASA products at a
  # point, asynchronously. Submit a point task, poll it, then read the results
  # CSV of one product. Earthdata Login credentials (EARTHDATA_USERNAME and
  # EARTHDATA_PASSWORD in the credentials; the account must have authorised
  # AppEEARS once) are exchanged for a 48 h bearer token, cached until an hour
  # before it expires. Failures raise DataSources::Client::Error.
  class Client
    BASE_URL = "https://appeears.earthdatacloud.nasa.gov/api/"
    TOKEN_KEY = "appeears/token/v1"
    TIMEOUT = 60
    DONE = "done"
    FAILED = "error"

    Error = DataSources::Client::Error

    def self.configured?
      credentials = Rails.application.credentials
      credentials.EARTHDATA_USERNAME.present? && credentials.EARTHDATA_PASSWORD.present?
    end

    def initialize(cache: Rails.cache)
      @cache = cache
    end

    # Starts a point task; returns its id. layers: [{ product:, layer: }, ...].
    def submit_point(name:, layers:, from:, to:, latitude:, longitude:, id:)
      body = {
        task_type: "point", task_name: name,
        params: { dates: [ { startDate: from.strftime("%m-%d-%Y"), endDate: to.strftime("%m-%d-%Y") } ],
                  layers: layers.map { |l| { product: l.fetch(:product), layer: l.fetch(:layer) } },
                  coordinates: [ { id: id, latitude: latitude.to_f.round(5), longitude: longitude.to_f.round(5) } ] }
      }
      authorized { api.post("task", body.to_json) }.fetch("task_id") { raise Error, "#{self.class.name}: no task id" }
    end

    # "pending", "queued", "processing", "done" or "error".
    def status(task_id) = authorized { api.get("task/#{task_id}") }["status"].to_s

    # The results CSV of one product of a finished task (as text).
    def results_csv(task_id, product:)
      files = Array(authorized { api.get("bundle/#{task_id}") }["files"])
      # AppEEARS names the file with dashes for the product's dots and underscores (ECO_L4T_ESI.002 -> ECO-L4T-ESI-002).
      suffix = "#{product.tr('._', '--')}-results.csv"
      file = files.find { |f| f["file_name"].to_s.end_with?(suffix) } or raise Error, "#{self.class.name}: no #{suffix} in the bundle"

      response = request { api.get("bundle/#{task_id}/#{file["file_id"]}") }
      response = request { Faraday.get(response.headers["location"]) } if response.status.between?(300, 399)
      raise Error, "#{self.class.name}: download failed (#{response.status})" unless response.success?

      response.body.to_s
    end

    private

    # Runs the call with the bearer token; logs in again once on a 401.
    def authorized
      response = request { yield }
      if response.status == 401
        @cache.delete(TOKEN_KEY)
        @token = nil
        response = request { yield }
      end
      raise Error, "#{self.class.name}: #{response.status} #{response.body.to_s[0, 200]}" unless response.success?

      response.body.is_a?(Hash) ? response.body : {}
    end

    def token
      @token ||= @cache.read(TOKEN_KEY) || login
    end

    def login
      raise Error, "#{self.class.name}: Earthdata credentials are missing" unless self.class.configured?

      credentials = Rails.application.credentials
      connection = Faraday.new(url: BASE_URL) do |f|
        f.request :authorization, :basic, credentials.EARTHDATA_USERNAME, credentials.EARTHDATA_PASSWORD
        f.response :json
        f.options.timeout = TIMEOUT
      end
      response = request { connection.post("login") { |r| r.headers["Content-Length"] = "0" } }
      raise Error, "#{self.class.name}: login failed (#{response.status})" unless response.status == 200

      expires = Time.zone.parse(response.body["expiration"].to_s) rescue nil
      ttl = expires ? [ expires - 1.hour - Time.current, 60 ].max : 1.hour
      @cache.write(TOKEN_KEY, response.body["token"], expires_in: ttl)
      response.body["token"]
    end

    def request
      Platform::Switchboard.guard!(:data)
      yield
    rescue Faraday::Error => e
      raise Error, "#{self.class.name}: #{e.class.name.demodulize} #{e.message}".truncate(250)
    end

    # Rebuilt per call so a fresh token is used after a 401.
    def api
      Faraday.new(url: BASE_URL, headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }) do |f|
        f.request :retry, max: 2, interval: 1, backoff_factor: 2, retry_statuses: [ 502, 503, 504 ], methods: %i[get]
        f.response :json, content_type: /\bjson$/
        f.options.timeout = TIMEOUT
        f.options.open_timeout = 10
      end
    end
  end
end
