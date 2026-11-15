module Onboarding
  # "Save selected" on the confirm card. Reads the staged proposal from the
  # session row (never from the request), keeps the accepted keys, runs them
  # through the allowlist again and writes profile, farm, main field and crops
  # in one transaction, then clears the proposal.
  #
  #   accepted: ["profile.budget_level", "farm.name", "field.area", "field.soil.texture", "crops.2025.main"]
  #   Success(applied: { "profile.budget_level" => "low", "field.soil.texture" => "medium",
  #                      "crops.2025.main" => { "crop_name" => "Corn", ... } })
  class ApplyProposalService < ApplicationService
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
      ActiveRecord::Base.transaction do
        apply_profile(rows[:profile], kept["profile"], applied)
        apply_farm(rows[:farm], kept["farm"], applied)
        apply_field(rows[:field], kept["field"], applied)
        apply_crops(rows[:field], kept["crops"], applied)
        session.update!(proposal: {})
      end
      Success(applied: applied)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end

    private

    def apply_profile(profile, attrs, applied)
      return if attrs.blank?

      profile.update!(attrs)
      attrs.each { |key, value| applied["profile.#{key}"] = value }
    end

    def apply_farm(farm, attrs, applied)
      return if attrs.blank?

      farm.update!(attrs)
      attrs.each { |key, value| applied["farm.#{key}"] = value }
    end

    def apply_field(field, attrs, applied)
      return if attrs.blank?

      soil = attrs["soil"]
      scalars = attrs.except("soil")
      field.assign_attributes(scalars)
      field.soil = field.soil.merge(soil) if soil.present?
      field.save!
      scalars.each { |key, value| applied["field.#{key}"] = value }
      soil&.each { |key, value| applied["field.soil.#{key}"] = value }
    end

    def apply_crops(field, rows, applied)
      Array(rows).each do |row|
        crop = field.field_crops.find_or_initialize_by(season_year: row["season_year"], role: row["role"])
        crop.assign_attributes(row.slice("crop_name", "scientific_name", "planting_month", "harvest_month").merge(source: "assistant"))
        crop.save!
        applied["crops.#{row['season_year']}.#{row['role']}"] = row
      end
    end
  end
end
