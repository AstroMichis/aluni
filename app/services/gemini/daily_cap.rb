module Gemini
  # A global ceiling on Gemini requests per UTC day, counted in Redis right
  # before each request (Gemini::Client#post_and_extract, after the switchboard
  # guard). The request that goes one over the limit pauses the gemini switch
  # (reason "daily_cap") and raises Platform::ServicePaused, which every caller
  # already handles like an operator pause. Resuming gemini (Platform switch,
  # platform:resume) clears the day's count, so the operator gets a fresh budget.
  #
  # Redis being down fails open: the cap is a safety net, not a gate.
  module DailyCap
    KEY_PREFIX = "gemini:daily_calls".freeze
    REASON = "daily_cap".freeze

    module_function

    def limit = Rails.configuration.x.gemini.daily_cap.to_i

    def enabled? = limit.positive?

    def key(now = Time.now.utc) = "#{KEY_PREFIX}:#{now.utc.to_date.iso8601}"

    # Counts one request; raises Platform::ServicePaused past the limit.
    def count!(redis: REDIS, now: Time.now.utc)
      return unless enabled?

      calls = increment(redis, key(now))
      return if calls.nil? || calls <= limit

      trip!(calls) if calls == limit + 1
      raise Platform::ServicePaused.new(:gemini)
    end

    def calls_today(redis: REDIS, now: Time.now.utc)
      redis.get(key(now)).to_i
    rescue Redis::BaseError
      0
    end

    def reset!(redis: REDIS, now: Time.now.utc)
      redis.del(key(now))
    rescue Redis::BaseError => e
      Rails.logger.warn("[Gemini::DailyCap] reset failed: #{e.class}: #{e.message}")
    end

    def increment(redis, day_key)
      calls = redis.incr(day_key)
      redis.expire(day_key, 2 * 24 * 3600) if calls == 1
      calls
    rescue Redis::BaseError => e
      Rails.logger.warn("[Gemini::DailyCap] Redis unavailable, not counting: #{e.class}: #{e.message}")
      nil
    end

    def trip!(calls)
      Rails.logger.error("[Gemini::DailyCap] #{calls - 1} requests today reached the cap of #{limit}; pausing gemini")
      Platform::ToggleService.call(service: "gemini", paused: true, reason: REASON, actor: REASON)
    end
  end
end
