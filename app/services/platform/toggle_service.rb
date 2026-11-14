# frozen_string_literal: true

module Platform
  # Pauses or resumes one service and records who did it on the switch row.
  # The actor comes from PLATFORM_ACTOR (set by the GitHub workflow) or the
  # shell user running the rake task.
  class ToggleService < ApplicationService
    def initialize(service:, paused:, reason: nil, actor: nil)
      @service = service.to_s
      @paused = paused
      @reason = reason.presence
      @actor = actor.presence || ENV["PLATFORM_ACTOR"].presence || ENV["USER"].presence || "operator"
    end

    def call
      switch = PlatformSwitch.find_or_initialize_by(service: @service)
      switch.assign_attributes(paused: @paused, reason: @reason, paused_by: @actor)
      return Failure(code: :invalid, message: switch.errors.full_messages.to_sentence) unless switch.save

      Switchboard.bust!
      CronControl.sync! if @service.in?(%w[cron jobs])
      Rails.logger.info("[platform] #{@paused ? 'paused' : 'resumed'} #{@service} by #{@actor}#{" (#{@reason})" if @reason}")
      Success(switch)
    end
  end
end
