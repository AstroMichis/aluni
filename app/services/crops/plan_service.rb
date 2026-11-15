# frozen_string_literal: true

module Crops
  # What the farmer plans to grow next season on a field, or on one zone of
  # it (Fields::Zone, by index): the zone's cells go to the crop and leave the
  # other planned crops; a blank crop clears them. The season is saved by
  # Fields::SeasonLayoutService, so a plan on the whole field stays one
  # whole-field row (role main, source farmer).
  class PlanService < ApplicationService
    def initialize(user:, field:, crop:, zone: nil)
      @user = user
      @field_id = field.to_s
      @crop = crop.to_s
      @zone = zone
    end

    def call
      record = Field.joins(:farm).where(farms: { user_id: @user.id }).includes(:field_crops).find_by(id: @field_id)
      return Failure(code: :not_found) unless record
      return Failure(code: :invalid) if @crop.present? && !Agronomy.find(@crop)

      field = Fields::Farm::Field.new(record, profile: Fields::Profile.current)
      zone = field.zone(@zone)
      Fields::SeasonLayoutService.call(user: @user, field: record.id, year: Date.current.year + 1, crops: layout(field, zone))
    end

    private

    # The plan's crops with the zone's cells taken from them and given to the new crop.
    def layout(field, zone)
      name = @crop.presence
      return [ { "crop" => name } ] if name && zone.whole_field?

      taken = zone.cells
      rows = field.plan_crops.filter_map do |crop|
        cells = crop.map_cells - taken
        { "crop" => crop.crop_name, "cells" => cells, "share" => share(crop, cells) } if cells.any?
      end
      return rows unless name

      same = rows.find { |r| Agronomy.find(r["crop"])&.key == name }
      if same
        same["cells"] += taken
        same["share"] = same["cells"].size / FieldCrop::GRID.to_f
      else
        rows << { "crop" => name, "cells" => taken, "share" => zone.share }
      end
      rows
    end

    # A crop that kept all its cells keeps its exact share.
    def share(crop, cells) = cells.size == crop.map_cells.size ? crop.portion : cells.size / FieldCrop::GRID.to_f
  end
end
