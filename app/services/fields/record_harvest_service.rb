# frozen_string_literal: true

module Fields
  # Records what one crop in one season yielded and earned, in the farmer's
  # own units (FieldCrop::YIELD_UNITS per hectare or acre, the price per that
  # unit, the cost per that area). Blank clears a value. Only a season that
  # has started can carry a harvest. Returns Success(field_crop).
  #
  #   values: { "yield_amount" => "11.2", "yield_unit" => "t", "area_basis" => "ha",
  #             "price" => "180", "cost" => "1200", "currency" => "USD" }
  class RecordHarvestService < ApplicationService
    FIELDS = %w[yield_amount yield_unit area_basis price cost currency].freeze
    NUMBERS = %w[yield_amount price cost].freeze

    def initialize(user:, crop_id:, values:)
      @user = user
      @crop_id = crop_id
      @values = values.to_h.stringify_keys.slice(*FIELDS)
    end

    def call
      crop = FieldCrop.joins(field: :farm).where(farms: { user_id: @user.id }).find_by(id: @crop_id)
      return Failure(code: :not_found) unless crop

      attributes = FIELDS.index_with { |key| clean(key, @values[key]) }
      return Failure(code: :invalid) if attributes.values_at(*NUMBERS).any?(:invalid)

      crop.assign_attributes(attributes)
      crop.save ? Success(crop) : Failure(code: :invalid, errors: crop.errors)
    end

    private

    # Numbers accept a comma as the decimal mark ("11,2"); blank is nil.
    def clean(key, value)
      text = value.to_s.strip
      return nil if text.empty?
      return text unless NUMBERS.include?(key)

      Float(text.delete(" ").tr(",", "."), exception: false)&.to_d || :invalid
    end
  end
end
