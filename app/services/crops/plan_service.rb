# frozen_string_literal: true

module Crops
  # Sets (or clears, with a blank crop) what the person plans to grow next on
  # a field. Takes the farm data, returns the updated copy.
  class PlanService < ApplicationService
    def initialize(data:, field:, crop:)
      @data = data.deep_dup
      @field = field.to_s
      @crop = crop.to_s
    end

    def call
      return Failure(code: :not_found) unless @data.dig("fields", @field)
      return Failure(code: :invalid) unless @crop.blank? || Catalog.all.key?(@crop)

      plans = @data["plans"].to_h
      @data["plans"] = @crop.blank? ? plans.except(@field) : plans.merge(@field => @crop)
      Success(@data)
    end
  end
end
