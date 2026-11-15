# frozen_string_literal: true

module Weather
  # Which weather alerts the person wants (they will be sent through
  # NotificationRouter once alerts run). Takes the farm data, returns the copy.
  class AlertsService < ApplicationService
    KINDS = %w[frost heat heavy_rain dry_spell].freeze

    def initialize(data:, alerts:)
      @data = data.deep_dup
      @alerts = Array(alerts).map(&:to_s).compact_blank
    end

    def call
      return Failure(code: :invalid) if (@alerts - KINDS).any?

      Success(@data.merge("alerts" => KINDS & @alerts))
    end
  end
end
