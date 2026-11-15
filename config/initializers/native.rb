# Deploy-time flags read through Platform::Features, never from ENV in app
# code, so specs and route constraints see one value.
#
# The web and the native shells are both first-class clients: sign-in, sign-up,
# passkey management and /app answer to browsers and to the Hotwire Native user
# agents alike. NATIVE_WEB_ACCESS=0 is an operator kill switch (NativeOnly) that
# sends browsers back to the landing page while the shells keep working.
Rails.application.config.x.native.web_access = ENV.fetch("NATIVE_WEB_ACCESS", "1") == "1"

# SIGNUPS_ENABLED=0 closes account creation while sign-in stays open.
Rails.application.config.x.signups.enabled = ENV.fetch("SIGNUPS_ENABLED", "1") == "1"
