# frozen_string_literal: true

module Fields
  # Saves one edit form: every datum of the farm (profile and farm) or of one
  # field at once, plus the source suggestions the farmer accepted. Values go
  # through Onboarding::Allowlist, the filter the chat's proposals pass, and
  # are written in one transaction. Only what changed is written: a crop
  # recorded by the chat keeps its origin unless the farmer changes it.
  #
  #   values:  { "irrigation" => "drip", "soil_problems" => ["", "weeds"],
  #              "location" => { "latitude" => "9.9", "longitude" => "-84.1" },
  #              "crop_history" => { "2024" => "Maíz" } }   blank = leave as is
  #   confirm: ["soil_texture", "crop_history"]             take the source's suggestion
  class SaveService < ApplicationService
    def initialize(user:, subject:, values: {}, confirm: [], profile: Profile.current)
      @user = user
      @subject = subject.to_s
      @values = values.to_h.stringify_keys
      @confirm = Array(confirm).map(&:to_s)
      @profile = profile
      @cdl_years = []
    end

    def call
      farm = Farm.for(@user)
      target = @subject == "farm" ? farm : farm.field(@subject)
      return Failure(code: :not_found) unless target

      updates = { "profile" => {}, "farm" => {}, "field" => {}, "soil" => {}, "crops" => {} }
      cleared = []
      @profile.data(target.level).select(&:column).each do |datum|
        value = @values[datum.key]
        value = proposal(target, datum) if @confirm.include?(datum.key) && blank?(value)
        if datum.multiple && value.is_a?(Array) && value.compact_blank.empty?
          cleared << datum.column
        elsif !blank?(value)
          collect(updates, datum, value, target)
        end
      end

      kept = Onboarding::Allowlist.filter(shape(updates))
      ActiveRecord::Base.transaction { apply(kept, cleared, target, farm) }
      Success(target.key)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end

    private

    def blank?(value) = value.respond_to?(:compact_blank) ? value.compact_blank.empty? : value.blank?

    # What "Use this suggestion" saves: the reading's proposal, or for the crop
    # history the crop-map years not recorded yet.
    def proposal(target, datum)
      return target.reading(datum).proposal unless datum.column == "crops.history"

      target.cdl_proposal.tap { |years| @cdl_years = years.keys.map(&:to_i) }
    end

    def collect(updates, datum, value, target)
      section, attr, sub = datum.column.split(".")
      case section
      when "profile", "farm" then updates[section][attr] = value
      when "field"
        if attr == "soil" then updates["soil"][sub] = value
        elsif attr == "location" then updates["field"].merge!(pin(value))
        else updates["field"][attr] = value
        end
      when "crops" then collect_crops(updates["crops"], attr, sub, value, target)
      end
    end

    def pin(value)
      lat, lon = value.is_a?(Hash) ? value.values_at("latitude", "longitude") : value.to_s.split(",")
      return {} if lat.blank? || lon.blank?

      { "latitude" => lat, "longitude" => lon, "location_source" => "typed", "location_confidence" => "confirmed" }
    end

    # Rows keyed by season so this season's crop and its months make one row.
    def collect_crops(rows, attr, sub, value, target)
      if attr == "history"
        value.to_h.compact_blank.each { |year, crop| rows[year.to_i] = (rows[year.to_i] || {}).merge(Crops::Agronomy.row(crop, year.to_i)) }
        return
      end

      current = target.current_crop
      year = current&.season_year || Date.current.year
      row = rows[year] ||= { "season_year" => year, "role" => "main", "crop_name" => current&.crop_name }.compact
      if sub then row[sub] = value
      else row.merge!(Crops::Agronomy.row(value, year))
      end
    end

    def shape(updates)
      field = updates["field"].merge(updates["soil"].any? ? { "soil" => updates["soil"] } : {})
      { "profile" => updates["profile"], "farm" => updates["farm"], "field" => field, "crops" => updates["crops"].values }
    end

    def apply(kept, cleared, target, farm)
      profile = @user.farmer_profile || @user.create_farmer_profile!
      profile_attrs = kept["profile"].to_h.merge(cleared_lists(cleared, "profile"))
      profile.update!(profile_attrs) if profile_attrs.any?
      farm.farm.update!(kept["farm"]) if kept["farm"]
      return unless target.is_a?(Farm::Field)

      record = target.record
      field = kept["field"].to_h
      soil = field.delete("soil").to_h.merge(cleared_lists(cleared, "field.soil"))
      record.assign_attributes(field)
      record.soil = record.soil.merge(soil) if soil.any?
      record.save! if record.changed?
      Array(kept["crops"]).each { |row| save_crop(record, row) }
    end

    def cleared_lists(cleared, prefix)
      cleared.select { |c| c.start_with?("#{prefix}.") }.to_h { |c| [ c.split(".").last, [] ] }
    end

    def save_crop(record, row)
      crop = record.field_crops.find_or_initialize_by(season_year: row["season_year"], role: row["role"])
      crop.assign_attributes(row.except("season_year", "role"))
      return unless crop.changed?

      crop.source = @cdl_years.include?(crop.season_year) ? "cdl" : "farmer"
      crop.save!
    end
  end
end
