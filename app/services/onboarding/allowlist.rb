module Onboarding
  # The one place the chat's vocabulary is defined, read straight from the
  # models so the Gemini response schema (DraftReplyService) and the filter
  # that stages or applies a proposal can never drift apart.
  #
  # A proposal is a hash with string keys and up to four sections:
  #   { "profile" => { "budget_level" => "low", "goals" => ["rotation"] },
  #     "farm"    => { "name" => "Finca Ana" },
  #     "field"   => { "area" => 12.5, "area_unit" => "hectares", "latitude" => 9.93,
  #                    "soil" => { "texture" => "medium", "ph" => 6.1 } },
  #     "crops"   => [ { "season_year" => 2025, "role" => "main", "crop_name" => "Corn", ... } ] }
  #
  # The confirm card names each fact with an accepted key: "profile.budget_level",
  # "farm.name", "field.area", "field.soil.texture", "crops.2025.main". The pin
  # (latitude, longitude, place_label, location_confidence, location_source) is
  # one fact: accepting any of its keys accepts the whole pin.
  module Allowlist
    UNKNOWN = "unknown"

    PROFILE_ENUMS = {
      "role" => FarmerProfile.roles.keys - [ UNKNOWN ],
      "experience" => FarmerProfile.experiences.keys - [ UNKNOWN ],
      "team" => FarmerProfile.teams.keys - [ UNKNOWN ],
      "units" => FarmerProfile.units.keys,
      "land_tenure" => FarmerProfile.land_tenures.keys - [ UNKNOWN ],
      "budget_level" => FarmerProfile.budget_levels.keys - [ UNKNOWN ],
      "risk_tolerance" => FarmerProfile.risk_tolerances.keys - [ UNKNOWN ]
    }.freeze
    PROFILE_LISTS = {
      "goals" => FarmerProfile::GOALS,
      "equipment" => FarmerProfile::EQUIPMENT,
      "livestock" => FarmerProfile::LIVESTOCK,
      "market_channels" => FarmerProfile::MARKET_CHANNELS,
      "practices" => FarmerProfile::PRACTICES
    }.freeze
    PROFILE_SCALARS = { "team_size" => :positive_integer, "notes" => :long_text }.freeze

    FARM_SCALARS = { "name" => :text, "country_code" => :country_code, "admin_area" => :text }.freeze

    FIELD_ENUMS = {
      "area_unit" => Field.area_units.keys,
      "irrigation" => Field.irrigations.keys - [ UNKNOWN ],
      "water_source" => Field.water_sources.keys - [ UNKNOWN ],
      "cropping_intensity" => Field.cropping_intensities.keys - [ UNKNOWN ],
      "location_confidence" => Field.location_confidences.keys - [ UNKNOWN ],
      "location_source" => Field.location_sources.keys - [ UNKNOWN ]
    }.freeze
    FIELD_SCALARS = {
      "name" => :text, "area" => :positive_number, "latitude" => :latitude, "longitude" => :longitude,
      "place_label" => :text
    }.freeze
    # The pin travels as one fact.
    LOCATION_KEYS = %w[latitude longitude place_label location_confidence location_source].freeze

    SOIL_ENUMS = Field::SOIL.except("problems").freeze
    SOIL_PROBLEMS = Field::SOIL.fetch("problems")
    SOIL_SCALARS = { "ph" => :ph, "lab_test" => :boolean }.freeze
    SOIL_PREFIX = "soil_"

    CROP_ROLES = FieldCrop.roles.keys
    CROP_SCALARS = {
      "crop_name" => :text, "scientific_name" => :text, "season_year" => :year,
      "planting_month" => :month, "harvest_month" => :month
    }.freeze

    LOCATION_CONFIDENCES = %w[low medium high].freeze
    TEXT_MAX = 100
    LONG_TEXT_MAX = FarmerProfile::NOTES_MAX

    module_function

    # Drops unknown sections, keys and values from a model answer or a stored
    # proposal; returns a string-keyed hash with only the sections that kept
    # something. soil_* keys on the field fold into field["soil"].
    def filter(updates)
      return {} unless updates.respond_to?(:to_h)

      source = deep_stringify(updates.to_h)
      out = {}
      profile = filter_section(source["profile"], PROFILE_ENUMS, PROFILE_LISTS, PROFILE_SCALARS)
      farm = filter_section(source["farm"], {}, {}, FARM_SCALARS)
      field = filter_field(source["field"])
      crops = filter_crops(source["crops"])
      out["profile"] = profile if profile.any?
      out["farm"] = farm if farm.any?
      out["field"] = field if field.any?
      out["crops"] = crops if crops.any?
      out
    end

    # The accepted keys a proposal offers: "profile.goals", "field.soil.ph",
    # "crops.2025.main". The pin appears once as "field.latitude".
    def keys_for(proposal)
      keys = []
      proposal.fetch("profile", {}).each_key { |k| keys << "profile.#{k}" }
      proposal.fetch("farm", {}).each_key { |k| keys << "farm.#{k}" }
      proposal.fetch("field", {}).each do |k, v|
        next if LOCATION_KEYS.include?(k) && k != "latitude"

        k == "soil" ? v.each_key { |s| keys << "field.soil.#{s}" } : keys << "field.#{k}"
      end
      proposal.fetch("crops", []).each { |row| keys << "crops.#{row['season_year']}.#{row['role']}" }
      keys
    end

    # Keeps only the facts named in accepted (see keys_for). Returns a filtered proposal.
    def accept(proposal, accepted)
      accepted = Array(accepted).map(&:to_s)
      pin = accepted.intersect?(LOCATION_KEYS.map { |k| "field.#{k}" })
      out = {}
      %w[profile farm].each do |section|
        kept = proposal.fetch(section, {}).select { |k, _| accepted.include?("#{section}.#{k}") }
        out[section] = kept if kept.any?
      end
      field = proposal.fetch("field", {}).select do |k, _|
        LOCATION_KEYS.include?(k) ? pin : (k != "soil" && accepted.include?("field.#{k}"))
      end
      soil = proposal.dig("field", "soil") || {}
      soil = soil.select { |k, _| accepted.include?("field.soil.#{k}") }
      field["soil"] = soil if soil.any?
      out["field"] = field if field.any?
      crops = proposal.fetch("crops", []).select { |row| accepted.include?("crops.#{row['season_year']}.#{row['role']}") }
      out["crops"] = crops if crops.any?
      filter(out)
    end

    def filter_section(section, enums, lists, scalars)
      return {} unless section.is_a?(Hash)

      section.each_with_object({}) do |(key, value), out|
        if enums.key?(key)
          out[key] = value.to_s if enums[key].include?(value.to_s)
        elsif lists.key?(key)
          kept = filter_list(value, lists[key])
          out[key] = kept if kept.any?
        elsif scalars.key?(key)
          coerced = coerce(value, scalars[key])
          out[key] = coerced unless coerced.nil?
        end
      end
    end

    def filter_field(section)
      return {} unless section.is_a?(Hash)

      soil_input = section["soil"].is_a?(Hash) ? section["soil"].dup : {}
      section.each do |key, value|
        soil_input[key.delete_prefix(SOIL_PREFIX)] = value if key.start_with?(SOIL_PREFIX)
      end
      field = filter_section(section.except("soil"), FIELD_ENUMS, {}, FIELD_SCALARS)
      soil = filter_soil(soil_input)
      field["soil"] = soil if soil.any?
      field
    end

    def filter_soil(soil)
      return {} unless soil.is_a?(Hash)

      filter_section(deep_stringify(soil), SOIL_ENUMS, { "problems" => SOIL_PROBLEMS }, SOIL_SCALARS)
    end

    def filter_crops(rows)
      return [] unless rows.is_a?(Array)

      kept = rows.filter_map do |row|
        next unless row.is_a?(Hash)

        crop = filter_section(row, {}, {}, CROP_SCALARS)
        crop["role"] = row.key?("role") ? row["role"].to_s : CROP_ROLES.first
        next unless crop["crop_name"] && crop["season_year"] && CROP_ROLES.include?(crop["role"])

        crop
      end
      kept.reverse.uniq { |crop| [ crop["season_year"], crop["role"] ] }.reverse
    end

    def filter_list(value, allowed)
      Array(value).map(&:to_s).select { |v| allowed.include?(v) }.uniq
    end

    def coerce(value, kind)
      case kind
      when :text then text(value, TEXT_MAX)
      when :long_text then text(value, LONG_TEXT_MAX)
      when :country_code then (code = value.to_s.strip.upcase).match?(/\A[A-Z]{2}\z/) ? code : nil
      when :positive_integer then (n = integer(value)) && n.positive? ? n : nil
      when :positive_number then (n = number(value)) && n.positive? ? n : nil
      when :latitude then (n = number(value)) && n.between?(-90, 90) ? n : nil
      when :longitude then (n = number(value)) && n.between?(-180, 180) ? n : nil
      when :ph then (n = number(value)) && n.between?(0, 14) ? n : nil
      when :year then (n = integer(value)) && FieldCrop::YEARS.cover?(n) ? n : nil
      when :month then (n = integer(value)) && n.between?(1, 12) ? n : nil
      when :boolean then boolean(value)
      end
    end

    def text(value, max)
      return nil unless value.is_a?(String) || value.is_a?(Numeric)

      string = value.to_s.strip
      string.empty? ? nil : string[0, max]
    end

    def number(value)
      case value
      when Numeric then value.to_f.finite? ? value : nil
      when String then Float(value.strip, exception: false)
      end
    end

    def integer(value)
      case value
      when Integer then value
      when Float then value.finite? && value == value.floor ? value.to_i : nil
      when String then Integer(value.strip, 10, exception: false)
      end
    end

    def boolean(value)
      case value
      when true, false then value
      when String then { "true" => true, "yes" => true, "false" => false, "no" => false }[value.strip.downcase]
      end
    end

    def deep_stringify(hash)
      hash.to_h.deep_stringify_keys
    end
  end
end
