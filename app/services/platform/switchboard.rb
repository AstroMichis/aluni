# frozen_string_literal: true

module Platform
  # Read side of the operator's pause switches (PlatformSwitch rows).
  #
  # PLATFORM_PAUSE_ALL=1 pauses every service without touching the database,
  # the emergency brake for when the database or Redis is unreachable.
  #
  # Reads fail open: if the switch table cannot be read, nothing is paused, so
  # a database hiccup never takes the app down on top of itself.
  module Switchboard
    CACHE_KEY = "platform_switches/v1"
    CACHE_TTL = 15.seconds

    module_function

    def paused?(service)
      return true if pause_all_env?

      snapshot.fetch(service.to_s, false)
    end

    # Raises Platform::ServicePaused when the service is paused. Clients call
    # it right before the HTTP request.
    def guard!(service)
      raise ServicePaused.new(service) if paused?(service)
    end

    def snapshot
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { load_snapshot }
    rescue StandardError => e
      Rails.logger.warn("[Platform::Switchboard] cache read failed: #{e.class}: #{e.message}")
      load_snapshot
    end

    def bust!
      Rails.cache.delete(CACHE_KEY)
    rescue StandardError => e
      Rails.logger.warn("[Platform::Switchboard] cache bust failed: #{e.class}: #{e.message}")
    end

    def load_snapshot
      PlatformSwitch.paused.pluck(:service).to_h { |service| [ service, true ] }
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("[Platform::Switchboard] switches unreadable, failing open: #{e.message}")
      {}
    end

    def pause_all_env?
      ENV["PLATFORM_PAUSE_ALL"] == "1"
    end
  end
end
