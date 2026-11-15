# Counters live in Redis (REDIS_URL), independent of Rails.cache, so limits
# are shared across every web process. Tests keep Rails.cache (:null_store) so
# the suite is never throttled; throttle specs swap in a MemoryStore explicitly.
unless Rails.env.test?
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    # Same resolution as config/initializers/redis.rb (which loads after this file).
    url: ENV["REDIS_URL"].presence ||
         (Rails.env.production? ? Rails.application.credentials.dig(:redis, :url) : Rails.configuration.x.local_redis_url),
    namespace: "rack_attack"
  )
end

# Client IP as resolved by ActionDispatch::RemoteIp (runs earlier in the
# middleware stack). It honours X-Forwarded-For only from trusted proxies
# (private ranges by default, plus TRUSTED_PROXIES in production.rb), so a
# client cannot spoof its IP to dodge a throttle. Rack's own #ip is used only
# as a fallback when RemoteIp has not run.
class Rack::Attack::Request < ::Rack::Request
  def remote_ip
    (env["action_dispatch.remote_ip"] || ip).to_s
  end
end

# Passkey ceremonies and passkey management, with or without a locale prefix:
# /sign_in, /es/sign_in/options, /en/sign_up, /passkeys, /passkeys/options.
RACK_ATTACK_AUTH_PATH = %r{\A(?:/(?:en|es))?/(?:sign_in|sign_up|passkeys)(?:/options)?\z}

# The onboarding chat actions (each one may cost a Gemini call), with or
# without a locale prefix: /app/onboarding/message, /es/app/onboarding/skip.
RACK_ATTACK_ASSISTANT_PATH = %r{\A(?:/(?:en|es))?/app/onboarding/(?:message|undo|skip|complete|reset)\z}

# Place search and reverse geocoding (Nominatim behind the server): /places, /es/places/reverse.
RACK_ATTACK_PLACES_PATH = %r{\A(?:/(?:en|es))?/places(?:/reverse)?\z}

# Block obvious vulnerability scanners probing for common exploits
Rack::Attack.blocklist("vulnerability-scanners") do |req|
  req.path.match?(/\.(php|asp|aspx|jsp|cgi|bak|sql)$/i) ||
    req.path.match?(/^\/(\.git|\.env)/i) ||
    req.path.match?(/\/(wp-admin|wp-login|wp-content|wp-includes|xmlrpc)/i) ||
    req.path.match?(/(phpmyadmin|myadmin|pma|dbadmin)/i)
end

# General rate limiting (300 requests per 5 minutes per IP)
Rack::Attack.throttle("req/ip", limit: 300, period: 300) do |req|
  req.remote_ip unless req.path.start_with?("/assets", "/up")
end

# Authentication pages and endpoints (any verb)
Rack::Attack.throttle("auth/ip", limit: 20, period: 60) do |req|
  req.remote_ip if req.path.match?(RACK_ATTACK_AUTH_PATH)
end

# Passkey ceremonies (options + verification POSTs): stricter than page views.
Rack::Attack.throttle("passkey-ceremony/ip", limit: 8, period: 60) do |req|
  req.remote_ip if req.post? && req.path.match?(RACK_ATTACK_AUTH_PATH)
end

# Assistant turns (POST and DELETE): a burst limit and an hourly budget per IP.
# Strikes for abusive content live on the OnboardingSession row, not here.
Rack::Attack.throttle("assistant/ip/min", limit: 20, period: 60) do |req|
  req.remote_ip if (req.post? || req.delete?) && req.path.match?(RACK_ATTACK_ASSISTANT_PATH)
end

Rack::Attack.throttle("assistant/ip/hour", limit: 150, period: 3600) do |req|
  req.remote_ip if (req.post? || req.delete?) && req.path.match?(RACK_ATTACK_ASSISTANT_PATH)
end

# JSON API for the native screens
Rack::Attack.throttle("api/ip", limit: 120, period: 60) do |req|
  req.remote_ip if req.path.start_with?("/api/")
end

# Inbound webhooks
Rack::Attack.throttle("webhooks/ip", limit: 100, period: 60) do |req|
  req.remote_ip if req.path.start_with?("/webhooks")
end

# Sidekiq Web basic auth brute force
Rack::Attack.throttle("sidekiq/ip", limit: 10, period: 60) do |req|
  req.remote_ip if req.path.start_with?("/sidekiq")
end

# The field finder's geocoding (Nominatim allows one request per second in total).
Rack::Attack.throttle("places/ip", limit: 20, period: 60) do |req|
  req.remote_ip if req.path.match?(RACK_ATTACK_PLACES_PATH)
end

# Custom blocked response
Rack::Attack.blocklisted_responder = lambda do |_env|
  [ 403, { "Content-Type" => "text/plain" }, [ "Forbidden" ] ]
end
