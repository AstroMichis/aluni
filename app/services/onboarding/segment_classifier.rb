module Onboarding
  # Pure rules that name the kind of operation a profile describes, from the
  # snapshot alone (no Gemini). Areas are summed over the fields in hectares.
  # Thresholds are defaults the product will tune.
  class SegmentClassifier < ApplicationService
    ACRES_PER_HECTARE = 2.47105
    SMALLHOLDER_MAX_HA = 2
    SMALL_MAX_HA = 20
    MID_MAX_HA = 200
    OWN_CHANNELS = %w[own_use local_market].freeze
    BULK_CHANNELS = %w[wholesale contract export].freeze

    def initialize(user:)
      @user = user
    end

    def call
      snapshot = ProfileSnapshot.new(user: @user).to_h
      @profile = snapshot[:profile] || {}
      @area = hectares(snapshot[:fields])
      Success(segment: segment)
    end

    private

    def segment
      return "smallholder_subsistence" if smallholder?
      return "large_commercial" if large?
      return "mid_mechanized" if mid?
      return "small_commercial" if small_commercial?

      "unknown"
    end

    def smallholder?
      @area && @area < SMALLHOLDER_MAX_HA && %w[solo family].include?(team) && budget == "low" &&
        (channels - OWN_CHANNELS).empty?
    end

    def large?
      (@area && @area > MID_MAX_HA) || (team == "crew" && channels.intersect?(BULK_CHANNELS))
    end

    def mid?
      (@area && @area.between?(SMALL_MAX_HA, MID_MAX_HA)) ||
        (equipment.include?("tractor") && equipment.intersect?(%w[planter harvester]) && %w[small_team crew].include?(team))
    end

    def small_commercial?
      @area && @area < SMALL_MAX_HA && (channels - [ "own_use" ]).any?
    end

    def team = @profile[:team]
    def budget = @profile[:budget_level]
    def channels = Array(@profile[:market_channels])
    def equipment = Array(@profile[:equipment])

    def hectares(fields)
      sized = Array(fields).select { |f| f[:area] }
      return nil if sized.empty?

      sized.sum { |f| f[:area_unit] == "acres" ? f[:area] / ACRES_PER_HECTARE : f[:area] }
    end
  end
end
