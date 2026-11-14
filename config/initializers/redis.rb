# frozen_string_literal: true

# Single source of the Redis connection for Sidekiq, Action Cable, Rack::Attack
# and app code. REDIS_URL first, then the production credentials, then local.
REDIS_CONFIG = {
  url: ENV["REDIS_URL"].presence ||
       (Rails.env.production? ? Rails.application.credentials.dig(:redis, :url) : "redis://localhost:6379/1")
}.freeze

REDIS = Redis.new(**REDIS_CONFIG)
