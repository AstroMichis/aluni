require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Uploads live on Cloudflare R2 and are proxied through the app so the bucket stays private.
  # ACTIVE_STORAGE_SERVICE=local keeps them on the aluni_storage volume instead (no R2 account).
  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "cloudflare_r2").to_sym
  config.active_storage.resolve_model_to_route = :rails_storage_proxy

  # One canonical domain (APP_DOMAIN, set in config/deploy.yml) plus www.
  app_domain = ENV.fetch("APP_DOMAIN", "aluni.us")

  # Action Cable: WebSocket connections from the apex and www only.
  config.action_cable.allowed_request_origins = [
    /\Ahttps?:\/\/#{Regexp.escape(app_domain)}\z/,
    /\Ahttps?:\/\/www\.#{Regexp.escape(app_domain)}\z/
  ]

  # Passkeys: the RP id is the apex; both the apex and www may start a ceremony.
  config.x.webauthn.rp_id = app_domain
  config.x.webauthn.allowed_origins = [ "https://#{app_domain}", "https://www.#{app_domain}" ]

  # TLS terminates at kamal-proxy / Cloudflare; trust X-Forwarded-Proto.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Health checks hit /up over plain HTTP from the proxy.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Active Record encryption keys: credentials (active_record_encryption.*) or
  # ENV, e.g. Kamal secrets. Boot fails without them
  # (config/initializers/active_record_encryption.rb).
  %w[primary_key deterministic_key key_derivation_salt].each do |key|
    value = ENV["ACTIVE_RECORD_ENCRYPTION_#{key.upcase}"]
    config.active_record.encryption.public_send(:"#{key}=", value) if value.present?
  end
  # Keep reading legacy plaintext rows until `bin/rails encryption:backfill`
  # has run, then set AR_ENCRYPTION_SUPPORT_UNENCRYPTED_DATA=false.
  config.active_record.encryption.support_unencrypted_data =
    ENV.fetch("AR_ENCRYPTION_SUPPORT_UNENCRYPTED_DATA", "true") == "true"

  # Client IP resolution (request.remote_ip, also used by Rack::Attack).
  # Private ranges (kamal-proxy on the Docker network) are trusted by default.
  # When Cloudflare sits in front, list its published ranges as a comma-separated
  # TRUSTED_PROXIES so the real client IP is taken from X-Forwarded-For.
  if ENV["TRUSTED_PROXIES"].present?
    config.action_dispatch.trusted_proxies =
      ActionDispatch::RemoteIp::TRUSTED_PROXIES +
      ENV["TRUSTED_PROXIES"].split(",").map { |cidr| IPAddr.new(cidr.strip) }
  end

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Redis cache store on the same REDIS_URL as Sidekiq, namespaced.
  config.cache_store = :redis_cache_store, {
    url: ENV["REDIS_URL"].presence || Rails.application.credentials.dig(:redis, :url),
    namespace: "cache"
  }

  # Disable caching for Action Mailer templates even if Action Controller caching is enabled.
  config.action_mailer.perform_caching = false

  # SMTP settings come from credentials (smtp.*); pick a provider with a free
  # tier (Resend, Brevo) and add SPF/DKIM/DMARC at the DNS provider.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: app_domain, protocol: "https" }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: Rails.application.credentials.dig(:smtp, :address),
    port: Rails.application.credentials.dig(:smtp, :port) || 587,
    user_name: Rails.application.credentials.dig(:smtp, :user_name),
    password: Rails.application.credentials.dig(:smtp, :password),
    domain: Rails.application.credentials.dig(:smtp, :domain) || app_domain,
    authentication: :plain,
    enable_starttls_auto: true
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts = [ app_domain, "www.#{app_domain}", *ENV.fetch("ADMIN_HOST", "").split(",").map(&:strip) ].uniq

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
