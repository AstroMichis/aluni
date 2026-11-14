# Deploy-time flags for the native-first split. Read through Platform::Features,
# never from ENV in app code, so specs and route constraints see one value.
#
# The web site is informational; sign-in, sign-up, passkey management and /app
# answer only to the Hotwire Native user agents. NATIVE_WEB_ACCESS=1 opens them
# to regular browsers (default on in development so pages can be exercised
# without a device; off in test and production).
Rails.application.config.x.native.web_access =
  ENV.fetch("NATIVE_WEB_ACCESS") { Rails.env.development? ? "1" : "0" } == "1"

# SIGNUPS_ENABLED=0 closes account creation while sign-in stays open.
Rails.application.config.x.signups.enabled = ENV.fetch("SIGNUPS_ENABLED", "1") == "1"
