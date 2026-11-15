# Meteomatics Weather API (hackathon offer: 1,000 queries a day). Off until
# configured: credentials meteomatics.{username,password} or ENV
# METEOMATICS_USERNAME / METEOMATICS_PASSWORD. Platform::Features.meteomatics?
# answers false while either is missing.
credentials = Rails.application.credentials
Rails.application.config.x.meteomatics.username =
  credentials.dig(:meteomatics, :username).presence || ENV["METEOMATICS_USERNAME"].presence
Rails.application.config.x.meteomatics.password =
  credentials.dig(:meteomatics, :password).presence || ENV["METEOMATICS_PASSWORD"].presence
# Answers are cached per rounded point and hour so repeated views of the same
# field do not spend the daily quota.
Rails.application.config.x.meteomatics.cache_ttl =
  Integer(ENV["METEOMATICS_CACHE_TTL_SECONDS"].presence || 3600).seconds
