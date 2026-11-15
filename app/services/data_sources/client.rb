# frozen_string_literal: true

module DataSources
  # Shared plumbing for the public data-source clients (docs/data_sources/):
  # a Faraday connection with retries and explicit timeouts, the `data`
  # switch checked right before every request, and one error class. None of
  # these sources needs an account; each client turns its answer into a plain
  # hash that Fields::FetchObservationsJob stores as is.
  class Client
    class Error < StandardError; end

    OPEN_TIMEOUT = 5
    TIMEOUT = 25
    RETRY = { max: 2, interval: 0.5, backoff_factor: 2,
              exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::ServerError ] }.freeze

    def initialize(base_url = self.class::BASE_URL)
      @base_url = base_url
    end

    private

    def get(path, json: true, **params)
      request { connection(json).get(path, params).body }
    end

    def post_json(path, body)
      request { connection(true).post(path, body.to_json, "Content-Type" => "application/json").body }
    end

    def request
      Platform::Switchboard.guard!(:data)
      yield
    rescue Faraday::Error => e
      raise Error, "#{self.class.name}: #{e.class.name.demodulize} #{e.message}".truncate(250)
    end

    def connection(json)
      (@connections ||= {})[json] ||= Faraday.new(url: @base_url) do |f|
        f.request :retry, **RETRY
        f.response :json if json
        f.response :raise_error
        f.options.open_timeout = OPEN_TIMEOUT
        f.options.timeout = TIMEOUT
      end
    end
  end
end
