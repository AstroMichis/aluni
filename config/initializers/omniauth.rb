# Social sign-in (docs/AUTH.md, docs/INTEGRATIONS.md): Google, Apple and
# Microsoft through OmniAuth. A provider is registered only once its
# credentials exist (oauth.google.*, oauth.apple.*, oauth.microsoft.*), so
# nothing shows until it is configured; Platform::Features.oauth_providers
# lists the registered ones and the views read that. The `oauth` switch
# (Platform::Switchboard) pauses every provider at the request phase.
#
# The request phase is POST only, with Rails' CSRF token
# (omniauth-rails_csrf_protection). Callbacks land on
# OmniauthCallbacksController (routes: /auth/:provider/callback, /auth/failure).
#
# Apple answers with a cross-site form POST (response_mode=form_post) that
# carries no SameSite=Lax cookie, so its registered return URL is
# /auth/apple/return, a page of ours that re-posts the same fields to
# /auth/apple/callback from our own origin (OmniauthCallbacksController#apple_return).
require "omniauth"

credentials = Rails.application.credentials
origin = Array(Rails.configuration.x.webauthn.allowed_origins).first.to_s

providers = {}
if Rails.env.test?
  # Specs run every provider through OmniAuth.config.mock_auth, never the network.
  providers = {
    google_oauth2: [ "test-google-id", "test-google-secret", {} ],
    apple: [ "test.apple.id", "", { team_id: "TEAM", key_id: "KEY", pem: "" } ],
    microsoft_graph: [ "test-microsoft-id", "test-microsoft-secret", {} ]
  }
else
  google = credentials.dig(:oauth, :google) || {}
  if google[:client_id].present? && google[:client_secret].present?
    providers[:google_oauth2] = [ google[:client_id], google[:client_secret], { scope: "openid,email,profile", prompt: "select_account" } ]
  end

  apple = credentials.dig(:oauth, :apple) || {}
  if %i[client_id team_id key_id private_key].all? { |key| apple[key].present? }
    providers[:apple] = [ apple[:client_id], "", { team_id: apple[:team_id], key_id: apple[:key_id], pem: apple[:private_key] } ]
  end

  microsoft = credentials.dig(:oauth, :microsoft) || {}
  if microsoft[:client_id].present? && microsoft[:client_secret].present?
    # Microsoft addresses are never trusted for linking (Auth::SocialSignInService),
    # so the gem's nOAuth domain check is not needed; it also fails on personal
    # accounts without a mail address.
    providers[:microsoft_graph] = [ microsoft[:client_id], microsoft[:client_secret], { scope: "openid email profile User.Read", skip_domain_verification: true } ]
  end
end

# Apple's return URL must match what the Services ID registers, exactly.
if providers[:apple]
  providers[:apple].last[:redirect_uri] = "#{origin}/auth/apple/return"
  providers[:apple].last[:authorized_client_ids] = []
end

Rails.application.config.x.oauth.providers = providers.keys.map(&:to_s).freeze

OmniAuth.config.logger = Rails.logger
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true
# Callback URLs are built from the canonical origin, never from the Host header.
OmniAuth.config.full_host = origin if origin.present? && !Rails.env.test?
OmniAuth.config.test_mode = Rails.env.test?

# Every failure (cancelled, state mismatch, paused switch) lands on our controller.
OmniAuth.config.on_failure = ->(env) { OmniauthCallbacksController.action(:failure).call(env) }

# What the button's form carried waits in the session for the callback
# (OmniauthCallbacksController): the finder's field, the language, and whether
# this is "connect" from the account page rather than a sign-in.
OmniAuth.config.before_request_phase = lambda do |env|
  body = Rack::Request.new(env).POST
  env["rack.session"]["oauth_pending"] = {
    "locale" => body["locale"].to_s.presence,
    "intent" => (body["intent"] == "connect" ? "connect" : "sign_in"),
    "field" => Fields::SaveSetupService.coerce(body.slice(*Fields::SaveSetupService::KEYS))
  }.compact
end

# The operator's pause: while `oauth` is paused nothing leaves for the provider;
# the request phase lands on /auth/failure?message=paused instead (a middleware
# ahead of OmniAuth, since an exception there would never reach a controller).
class OmniauthPauseGate
  def initialize(app) = @app = app

  def call(env)
    if env["REQUEST_METHOD"] == "POST" && env["PATH_INFO"].to_s.match?(%r{\A/auth/[a-z_0-9]+/?\z}) && Platform::Switchboard.paused?(:oauth)
      return [ 303, { "location" => "/auth/failure?message=paused" }, [] ]
    end

    @app.call(env)
  end
end
Rails.application.config.middleware.use OmniauthPauseGate

Rails.application.config.middleware.use OmniAuth::Builder do
  providers.each do |name, (client_id, client_secret, options)|
    provider name, client_id, client_secret, options
  end
end
