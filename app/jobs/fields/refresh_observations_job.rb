# frozen_string_literal: true

module Fields
  # Keeps every located field's public data fresh without flooding the
  # sources (config/sidekiq_cron.yml):
  #
  #   weekly   the season so far (NASA POWER) and the last year's NDVI, the
  #            data that move week to week, for fields fetched over STALE_WEEKLY ago
  #   monthly  everything Fields::FetchObservationsJob asks for, including the
  #            AppEEARS products, for fields whose oldest data is over STALE_MONTHLY old
  #
  # Fields are spread out (SPACING) because Planetary Computer rate-limits
  # bursts and AppEEARS runs one task at a time per account.
  class RefreshObservationsJob < ApplicationJob
    queue_as :maintenance

    STALE_WEEKLY = 6.days
    STALE_MONTHLY = 28.days
    SPACING = { "weekly" => 3.minutes, "monthly" => 10.minutes }.freeze

    def perform(pass = "weekly")
      pass = pass.to_s
      raise ArgumentError, "unknown pass #{pass}" unless SPACING.key?(pass)

      stale(pass).each_with_index do |field, i|
        job = FetchObservationsJob.set(wait: SPACING.fetch(pass) * i)
        pass == "weekly" ? job.perform_later(field.id, only: FetchObservationsJob::QUICK) : job.perform_later(field.id)
      end
    end

    private

    def stale(pass)
      Field.includes(:observations).order(:id).select do |field|
        next false unless field.located?

        observations = field.observations
        if pass == "weekly"
          power = observations.find { |o| o.source == "nasa_power" }
          power.nil? || power.fetched_at.nil? || power.fetched_at < STALE_WEEKLY.ago
        else
          observations.empty? || observations.map { |o| o.fetched_at || Time.at(0) }.min < STALE_MONTHLY.ago
        end
      end
    end
  end
end
