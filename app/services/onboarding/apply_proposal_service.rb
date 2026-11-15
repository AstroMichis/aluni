module Onboarding
  # Writes the staged proposal. Reads it from the session row (never from the
  # request), keeps the accepted keys, runs them through the allowlist again
  # and writes profile, farm, main field and crops in one transaction, then
  # clears the proposal. Before every write it captures what was there, so
  # UndoApplyService can put it back from session.last_applied.
  #
  #   accepted: ["profile.budget_level", "farm.name", "field.area", "field.soil.texture", "crops.2025.main"]
  #   Success(applied: { "profile.budget_level" => "low", "field.soil.texture" => "medium",
  #                      "crops.2025.main" => { "crop_name" => "Corn", ... } },
  #           before:  { "profile" => { "budget_level" => "unknown" },
  #                      "field" => { "area" => nil }, "soil" => { "ph" => 6.5 },
  #                      "crops" => [ { "season_year" => 2025, "role" => "main", "new_record" => true } ] })
  class ApplyProposalService < ApplicationService
    CROP_ATTRIBUTES = %w[crop_name scientific_name planting_month harvest_month source].freeze

    def initialize(user:, accepted:)
      @user = user
      @accepted = Array(accepted).map(&:to_s)
    end

    def call
      rows = step EnsureProfileService.call(user: @user)
      session = rows[:session]
      return Failure(code: :expired) if session.proposal.blank?

      kept = Allowlist.accept(session.proposal, @accepted)
      applied = {}
      before = {}
      ActiveRecord::Base.transaction do
        apply_profile(rows[:profile], kept["profile"], applied, before)
        apply_farm(rows[:farm], kept["farm"], applied, before)
        apply_field(rows[:field], kept["field"], applied, before)
        apply_crops(rows[:field], kept["crops"], applied, before)
        session.update!(proposal: {})
      end
      Success(applied: applied, before: before)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end

    private

    def apply_profile(profile, attrs, applied, before)
      return if attrs.blank?

      before["profile"] = profile.attributes.slice(*attrs.keys)
      profile.update!(attrs)
      attrs.each { |key, value| applied["profile.#{key}"] = value }
    end

    def apply_farm(farm, attrs, applied, before)
      return if attrs.blank?

      before["farm"] = farm.attributes.slice(*attrs.keys)
      farm.update!(attrs)
      attrs.each { |key, value| applied["farm.#{key}"] = value }
    end

    def apply_field(field, attrs, applied, before)
      return if attrs.blank?

      soil = attrs["soil"]
      scalars = attrs.except("soil")
      before["field"] = field.attributes.slice(*scalars.keys) if scalars.any?
      before["soil"] = field.soil.deep_dup if soil.present?
      field.assign_attributes(scalars)
      field.soil = field.soil.merge(soil) if soil.present?
      field.save!
      scalars.each { |key, value| applied["field.#{key}"] = value }
      soil&.each { |key, value| applied["field.soil.#{key}"] = value }
    end

    def apply_crops(field, rows, applied, before)
      return if rows.blank?

      before["crops"] = []
      Array(rows).each do |row|
        crop = field.field_crops.find_or_initialize_by(season_year: row["season_year"], role: row["role"])
        before["crops"] << crop_before(crop, row)
        crop.assign_attributes(row.slice("crop_name", "scientific_name", "planting_month", "harvest_month").merge(source: "assistant"))
        crop.save!
        applied["crops.#{row['season_year']}.#{row['role']}"] = row
      end
    end

    def crop_before(crop, row)
      entry = { "season_year" => row["season_year"], "role" => row["role"] }
      if crop.new_record?
        entry.merge("new_record" => true)
      else
        entry.merge("attributes" => crop.attributes.slice(*CROP_ATTRIBUTES))
      end
    end
  end
end
