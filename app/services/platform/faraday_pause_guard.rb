# frozen_string_literal: true

module Platform
  # Faraday middleware for clients with several connections: refuses the
  # request while the operator has the service paused.
  #
  #   Faraday.new(url) { |f| f.use Platform::FaradayPauseGuard, service: :gemini }
  class FaradayPauseGuard < Faraday::Middleware
    def initialize(app, service:)
      super(app)
      @service = service
    end

    def call(env)
      Switchboard.guard!(@service)
      @app.call(env)
    end
  end
end
