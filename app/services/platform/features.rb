# frozen_string_literal: true

module Platform
  # Deploy-time flags, each set in an initializer from ENV or credentials and
  # read here, never from ENV directly in app code, so specs and route
  # constraints see the same value.
  module Features
    module_function

    # NATIVE_WEB_ACCESS=1: regular browsers may reach sign-in, sign-up,
    # passkeys and /app (config/initializers/native.rb).
    def native_web_access? = Rails.configuration.x.native.web_access == true

    # SIGNUPS_ENABLED=0 closes account creation while sign-in stays open.
    def signups_enabled? = Rails.configuration.x.signups.enabled == true

    # Sidekiq Web is mounted only with basic-auth credentials (config/initializers/sidekiq_web.rb).
    def sidekiq_web?
      Rails.configuration.x.sidekiq_web.username.present? && Rails.configuration.x.sidekiq_web.password.present?
    end

    # Gemini is callable once its backend is configured: an API key (credentials
    # gemini.api_key) or, with GEMINI_BACKEND=vertex, a Google Cloud project.
    def gemini? = Gemini::Client.configured?

    # Native push is configured when either APNs or FCM credentials exist (config/push.yml).
    def push?
      Rails.application.credentials.dig(:action_push_native, :apns, :key_id).present? ||
        Rails.application.credentials.dig(:action_push_native, :fcm, :project_id).present?
    end

    # Outgoing mail is configured in production once SMTP credentials exist; development
    # writes mail to tmp/mails and test keeps it in memory, so both count as configured.
    def mail? = !Rails.env.production? || Rails.application.credentials.dig(:smtp, :address).present?

    # Web Push needs VAPID keys (credentials web_push.*; `bin/rails web_push:vapid_keys`).
    def web_push? = Rails.application.credentials.dig(:web_push, :public_key).present?

    # Social sign-in providers registered with OmniAuth (config/initializers/omniauth.rb):
    # each one appears once its credentials exist (oauth.google.*, oauth.apple.*, oauth.microsoft.*).
    def oauth_providers = Array(Rails.configuration.x.oauth.providers)

    def oauth?(provider) = oauth_providers.include?(provider.to_s)
  end
end
  end
end
