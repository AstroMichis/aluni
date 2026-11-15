module Onboarding
  # "Undo" on the toast after an auto-applied turn: puts back what
  # ApplyProposalService captured in session.last_applied["before"] (profile
  # and field attributes, the field's old soil hash, crops destroyed when they
  # were new or restored to their old attributes) in one transaction, then
  # clears last_applied so a second tap has nothing to undo.
  #
  #   Onboarding::UndoApplyService.call(user:)
  #   => Success(restored: { "profile.budget_level" => "unknown", "field.area" => nil,
  #                          "field.soil" => { "ph" => 6.5 }, "crops.2025.main" => nil })
  #   => Failure(code: :nothing_to_undo)
  class UndoApplyService < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      rows = step EnsureProfileService.call(user: @user)
      session = rows[:session]
      before = before_from(session.last_applied)
      return Failure(code: :nothing_to_undo) if before.blank?

      restored = {}
      ActiveRecord::Base.transaction do
        restore_attributes(rows[:profile], "profile", before["profile"], restored)
        restore_attributes(rows[:farm], "farm", before["farm"], restored)
        restore_field(rows[:field], before, restored)
        restore_crops(rows[:field], before["crops"], restored)
        session.update!(last_applied: {})
      end
      Success(restored: restored)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end

    private

    def before_from(last_applied)
      return nil unless last_applied.is_a?(Hash)

      before = last_applied["before"]
      before.is_a?(Hash) ? before : nil
    end

    def restore_attributes(record, section, attrs, restored)
      return unless attrs.is_a?(Hash) && attrs.any?

      record.update!(attrs)
      attrs.each { |key, value| restored["#{section}.#{key}"] = value }
    end

    def restore_field(field, before, restored)
      attrs = before["field"].is_a?(Hash) ? before["field"] : {}
      soil = before.key?("soil") ? before["soil"] : nil
      return if attrs.empty? && soil.nil?

      field.assign_attributes(attrs)
      field.soil = soil.is_a?(Hash) ? soil : {} unless soil.nil?
      field.save!
      attrs.each { |key, value| restored["field.#{key}"] = value }
      restored["field.soil"] = field.soil unless soil.nil?
    end

    def restore_crops(field, rows, restored)
      Array(rows).each do |row|
        next unless row.is_a?(Hash) && row["season_year"] && row["role"]

        key = "crops.#{row['season_year']}.#{row['role']}"
        crop = (row["id"] && field.field_crops.find_by(id: row["id"])) || field.field_crops.find_by(season_year: row["season_year"], role: row["role"])
        if row["new_record"]
          crop&.destroy!
          restored[key] = nil
        elsif row["attributes"].is_a?(Hash)
          crop ||= field.field_crops.build(season_year: row["season_year"], role: row["role"])
          crop.update!(row["attributes"].slice(*ApplyProposalService::CROP_ATTRIBUTES))
          restored[key] = row["attributes"]
        end
      end
    end
  end
end
