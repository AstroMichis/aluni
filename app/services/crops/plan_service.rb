# frozen_string_literal: true

module Crops
  # What the farmer plans to grow next season on a field: a FieldCrop for
  # next year (role main, source farmer), or none with a blank crop.
  class PlanService < ApplicationService
    def initialize(user:, field:, crop:)
      @user = user
      @field_id = field.to_s
      @crop = crop.to_s
    end

    def call
      field = Field.joins(:farm).where(farms: { user_id: @user.id }).find_by(id: @field_id)
      return Failure(code: :not_found) unless field

      year = Date.current.year + 1
      plan = field.field_crops.find_or_initialize_by(season_year: year, role: "main")
      return Success(plan.tap { plan.destroy if plan.persisted? }) if @crop.blank?

      return Failure(code: :invalid) unless Catalog.find(@crop)

      plan.update!(Catalog.row(@crop, year).slice("crop_name", "scientific_name").merge(source: "farmer"))
      Success(plan)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end
  end
end
