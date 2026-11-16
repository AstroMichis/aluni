# frozen_string_literal: true

module Fields
  # Adds a field from the add-a-field form: the pin, a name, the area and
  # how it is watered, this season's crop and the seasons before. Everything
  # passes Onboarding::Allowlist first; the pin enqueues the data fetch
  # (Field#after_commit). Returns Success(field), or Failure with code
  # :invalid_location (no valid pin), :too_many or :invalid (messages); nothing
  # is written on a failure, not even the farm.
  class CreateFieldService < ApplicationService
    MAX_FIELDS = 30

    def initialize(user:, attributes:, crop: nil, planting_month: nil, harvest_month: nil, history: {})
      @user = user
      @attributes = attributes.to_h.stringify_keys
      @crop = crop.presence
      @months = { "planting_month" => planting_month, "harvest_month" => harvest_month }.compact_blank
      @history = history.to_h.compact_blank
    end

    def call
      field_attrs = Onboarding::Allowlist.filter("field" => @attributes.merge(location))["field"].to_h
      return Failure(code: :invalid_location) unless field_attrs["latitude"] && field_attrs["longitude"]
      return Failure(code: :too_many) if @user.farms.first&.fields&.count.to_i >= MAX_FIELDS

      field = ActiveRecord::Base.transaction do
        farm = @user.farms.first || @user.farms.create!
        record = farm.fields.create!(field_attrs.except("soil").merge("position" => farm.fields.maximum(:position).to_i + 1))
        crops.each { |row| record.field_crops.create!(row.merge("source" => "farmer")) }
        record
      end
      Success(field)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end

    private

    def location
      return {} if @attributes["latitude"].blank?

      { "location_source" => @attributes["location_source"].presence || "typed", "location_confidence" => "confirmed" }
    end

    def crops
      rows = @history.map { |year, crop| Crops::Agronomy.row(crop, year.to_i) }
      rows << Crops::Agronomy.row(@crop, Date.current.year).merge(@months) if @crop
      Onboarding::Allowlist.filter("crops" => rows)["crops"].to_a
    end
  end
end
