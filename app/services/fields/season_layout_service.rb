# frozen_string_literal: true

module Fields
  # Saves how a season splits a field between crops (the "Plan the planting"
  # screen): each crop with the share of the field it covers and its cells on
  # the field map. Replaces the season's main crops in one transaction,
  # keeping each crop's months and source when it stays. One crop on the
  # whole field is stored as a whole field (no share, no cells), the shape
  # every single-crop writer uses. A crop sent without cells, or with cells
  # that no longer match its share (the form without JavaScript), gets them
  # from Fields::CellLayout. Returns Success(rows).
  class SeasonLayoutService < ApplicationService
    MAX_CROPS = 6
    PAST_SEASONS = 3
    TOLERANCE = 0.005
    MONTHS = %w[planting_month harvest_month].freeze

    def self.years = ((Date.current.year - PAST_SEASONS)..(Date.current.year + 1))

    def initialize(user:, field:, year:, crops:)
      @user = user
      @field_id = field.to_s
      @year = year.to_i
      @input = Array(crops).map { |c| c.to_h.stringify_keys }.reject { |c| c["crop"].to_s.strip.empty? }
    end

    def call
      field = Field.joins(:farm).where(farms: { user_id: @user.id }).find_by(id: @field_id)
      return Failure(code: :not_found) unless field
      return Failure(code: :year) unless self.class.years.cover?(@year)
      return Failure(code: :too_many) if @input.size > MAX_CROPS

      rows = step(build_rows)
      Success(save(field, rows))
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end

    private

    def build_rows
      rows = @input.map { |c| crop_row(c) }
      return Failure(code: :duplicate) if rows.map { |r| FieldCrop.key_for(r["crop_name"], r["scientific_name"]) }.uniq.size < rows.size
      return Success(rows.each { |r| r.merge!("share" => nil, "cells" => []) }) if whole_field?(rows)

      shares = rows.map { |r| r["share"] }
      return Failure(code: :share) if shares.any? { |s| s.nil? || s <= 0 || s > 1 }
      return Failure(code: :over) if shares.sum > 1 + TOLERANCE

      cells = rows.map { |r| r["cells"] }
      return Failure(code: :overlap) if cells.flatten.uniq.size < cells.flatten.size

      placed = CellLayout.allocate(shares, cells)
      kept = rows.each_with_index.map { |r, i| painted?(r) ? r["cells"].sort : placed[i] }
      kept = placed if kept.flatten.uniq.size < kept.flatten.size
      rows.each_with_index { |r, i| r["cells"] = kept[i] }
      return Failure(code: :share) if rows.any? { |r| r["cells"].empty? }

      Success(rows)
    end

    # Cells painted on the map that match the share (within a cell of
    # rounding) are kept as painted; stale or missing ones are placed again.
    def painted?(row) = row["cells"].any? && (row["cells"].size - (row["share"] * FieldCrop::GRID)).abs <= 1

    # One crop and either no share or (nearly) all of the field.
    def whole_field?(rows)
      rows.size == 1 && (rows.first["share"].nil? || rows.first["share"] >= 1 - TOLERANCE)
    end

    def crop_row(input)
      text = input["crop"].to_s.strip.first(FieldCrop::NAME_MAX)
      row = Crops::Agronomy.row(text, @year).slice("crop_name", "scientific_name")
      if row["scientific_name"].nil? && (hit = Crops::Catalog.find(text))
        row = { "crop_name" => hit[:crop_name], "scientific_name" => hit[:scientific_name].presence }.compact
      end
      share = input["share"].presence && input["share"].to_f.round(4)
      cells = Array(input["cells"].is_a?(String) ? input["cells"].split(",") : input["cells"]).filter_map { |c| Integer(c, exception: false) }
      row.merge("share" => share, "cells" => cells.select { |c| c.between?(0, FieldCrop::GRID - 1) }.uniq,
                "months" => input.slice(*MONTHS).transform_values { |m| m.presence&.to_i })
    end

    def save(field, rows)
      ActiveRecord::Base.transaction do
        existing = field.field_crops.where(season_year: @year, role: :main).index_by(&:crop_key)
        keep = rows.map { |r| FieldCrop.key_for(r["crop_name"], r["scientific_name"]) }
        existing.except(*keep).each_value(&:destroy!)
        rows.map do |r|
          crop = existing[FieldCrop.key_for(r["crop_name"], r["scientific_name"])] ||
                 field.field_crops.build(season_year: @year, role: :main, source: :farmer)
          crop.assign_attributes(r.slice("crop_name", "scientific_name", "share", "cells").merge(r["months"]))
          crop.save! if crop.changed?
          crop
        end
      end
    end
  end
end
