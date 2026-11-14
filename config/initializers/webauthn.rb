# Passkeys (WebAuthn). The relying party id and the allowed origins are set per
# environment (config.x.webauthn in config/environments/*.rb) because a passkey
# is bound to its RP id: development uses localhost, production the APP_DOMAIN
# apex. Native app origins (android:apk-key-hash:...) can be appended to
# allowed_origins when a native bridge component performs the ceremony.
WebAuthn.configure do |config|
  config.allowed_origins = Array(Rails.configuration.x.webauthn.allowed_origins)
  config.rp_id = Rails.configuration.x.webauthn.rp_id
  config.rp_name = "Aluni"
  config.credential_options_timeout = 120_000
end
