module Gemini
  # OAuth access token for Vertex AI from the GCE metadata server, i.e. the
  # service account attached to the VM (needs roles/aiplatform.user and the
  # cloud-platform scope). No key on disk. Tokens last about an hour; this caches
  # one per process and refreshes it a few minutes before it expires.
  class VertexToken
    METADATA_URL = "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token".freeze
    REFRESH_MARGIN = 300 # seconds

    class Error < StandardError; end

    @mutex = Mutex.new
    @token = nil
    @expires_at = Time.at(0)

    class << self
      def fetch
        @mutex.synchronize do
          refresh! if @token.nil? || Time.now >= @expires_at - REFRESH_MARGIN
          @token
        end
      end

      def reset!
        @mutex.synchronize { @token = nil; @expires_at = Time.at(0) }
      end

      private

      def refresh!
        response = Faraday.get(METADATA_URL, nil, "Metadata-Flavor" => "Google") do |req|
          req.options.timeout = 5
          req.options.open_timeout = 2
        end
        raise Error, "could not get a Vertex AI token: metadata server returned #{response.status}" unless response.success?

        data = JSON.parse(response.body)
        @token = data.fetch("access_token")
        @expires_at = Time.now + data.fetch("expires_in").to_i
      rescue Faraday::Error, JSON::ParserError, KeyError => e
        raise Error, "could not get a Vertex AI token: #{e.message}"
      end
    end
  end
end
