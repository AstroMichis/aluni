# frozen_string_literal: true

module Weather
  # Which weather alerts the farmer wants, kept in
  # FarmerProfile#notification_preferences["weather"] (sent through
  # NotificationRouter once alerts run).
  class AlertsService < ApplicationService
    KINDS = %w[frost heat heavy_rain dry_spell].freeze

    def initialize(user:, alerts:)
      @user = user
      @alerts = Array(alerts).map(&:to_s).compact_blank
    end

    def call
      return Failure(code: :invalid) if (@alerts - KINDS).any?

      profile = @user.farmer_profile || @user.create_farmer_profile!
      profile.update!(notification_preferences: profile.notification_preferences.to_h.merge("weather" => KINDS & @alerts))
      Success(profile)
    end
  end
end
