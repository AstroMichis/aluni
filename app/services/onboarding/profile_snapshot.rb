module Onboarding
  # One view of everything the chat has saved for a user. #to_h feeds the
  # profile preview (nil where nothing is known), #to_prompt the system prompt
  # ("unknown" where nothing is known, so the model asks instead of guessing),
  # #required_known? decides whether a topic's facts are in.
  class ProfileSnapshot
    PROFILE_ENUMS = %i[role experience team units land_tenure budget_level risk_tolerance segment].freeze
    PROFILE_LISTS = %i[goals equipment livestock market_channels practices].freeze
    FIELD_ENUMS = %i[location_confidence location_source area_unit irrigation water_source cropping_intensity].freeze
    # Facts that count toward #completeness.
    KEY_FACTS = %w[profile.role profile.experience profile.team field.latitude field.area field.irrigation
                   field.soil.texture crops profile.budget_level profile.goals].freeze

    def initialize(user:)
      @user = user
    end

    def profile = @profile ||= @user.farmer_profile
    def farm = @farm ||= @user.farms.first
    def fields = @fields ||= farm ? farm.fields.to_a : []
    def field = fields.first
    def crops = @crops ||= fields.flat_map { |f| f.field_crops.to_a }
    def session = @session ||= @user.onboarding_session

    def to_h
      {
        profile: profile_hash,
        farm: farm_hash,
        field: field_hash(field),
        fields: fields.map { |f| field_hash(f) },
        crops: crops.map { |c| crop_hash(c) },
        session: session && { topic: session.topic, status: session.status, turns: session.turns_count }
      }
    end

    def to_prompt
      lines = [ "FARMER: #{@user.display_name}" ]
      h = to_h
      PROFILE_ENUMS.each { |k| lines << "profile.#{k}: #{h[:profile]&.dig(k) || 'unknown'}" }
      lines << "profile.team_size: #{h[:profile]&.dig(:team_size) || 'unknown'}"
      PROFILE_LISTS.each { |k| lines << "profile.#{k}: #{list_or_unknown(h[:profile]&.dig(k))}" }
      lines << "farm: #{farm_line(h[:farm])}"
      if fields.empty?
        lines << "fields: none yet"
      else
        fields.each_with_index { |f, i| lines << "field [ID:#{f.id}] #{i.zero? ? '(main) ' : ''}#{field_line(f)}" }
      end
      if crops.empty?
        lines << "crops: none recorded"
      else
        crops.each { |c| lines << "crop [ID:#{c.id}] #{crop_line(c)}" }
      end
      lines.join("\n")
    end

    # keys like "field.latitude", "field.soil.texture", "profile.goals", "crops".
    def required_known?(keys)
      Array(keys).all? { |key| known?(key) }
    end

    def completeness
      known = KEY_FACTS.count { |key| known?(key) }
      known.fdiv(KEY_FACTS.size)
    end

    private

    def known?(key)
      case key.to_s
      when "crops" then crops.any?
      when /\Afield\.soil\.(\w+)\z/ then present_value?(field&.soil&.dig(Regexp.last_match(1)))
      when /\Afield\.(\w+)\z/ then present_value?(field_hash(field)&.dig(Regexp.last_match(1).to_sym))
      when /\Aprofile\.(\w+)\z/ then present_value?(profile_hash&.dig(Regexp.last_match(1).to_sym))
      when /\Afarm\.(\w+)\z/ then present_value?(farm_hash&.dig(Regexp.last_match(1).to_sym))
      else false
      end
    end

    def present_value?(value)
      return false if value.nil?
      return value.any? if value.is_a?(Array)
      return true if value == false

      value.present?
    end

    def profile_hash
      return nil unless profile

      hash = PROFILE_ENUMS.to_h { |k| [ k, enum_or_nil(profile, k) ] }
      hash[:team_size] = profile.team_size
      PROFILE_LISTS.each { |k| hash[k] = profile.public_send(k) }
      hash[:notes] = profile.notes
      hash
    end

    def farm_hash
      return nil unless farm

      { name: farm.name.presence, country_code: farm.country_code, admin_area: farm.admin_area }
    end

    def field_hash(record)
      return nil unless record

      hash = {
        id: record.id, name: record.name.presence, position: record.position,
        latitude: record.latitude&.to_f, longitude: record.longitude&.to_f, place_label: record.place_label,
        area: record.area&.to_f, soil: record.soil
      }
      FIELD_ENUMS.each { |k| hash[k] = enum_or_nil(record, k) }
      hash[:area_unit] = record.area_unit # a unit is never unknown
      hash
    end

    def crop_hash(record)
      {
        id: record.id, field_id: record.field_id, season_year: record.season_year, crop_name: record.crop_name,
        scientific_name: record.scientific_name, role: record.role, planting_month: record.planting_month,
        harvest_month: record.harvest_month, source: record.source
      }
    end

    def enum_or_nil(record, attribute)
      value = record.public_send(attribute)
      value == "unknown" ? nil : value
    end

    def list_or_unknown(list)
      Array(list).empty? ? "unknown" : Array(list).join(", ")
    end

    def farm_line(hash)
      return "unknown" unless hash

      [ hash[:name], hash[:admin_area], hash[:country_code] ].compact.join(", ").presence || "unknown"
    end

    def field_line(record)
      h = field_hash(record)
      pin = h[:latitude] ? "pin #{h[:latitude]}, #{h[:longitude]} (#{h[:location_confidence] || 'unknown'})" : "pin unknown"
      area = h[:area] ? "#{h[:area]} #{h[:area_unit]}" : "area unknown"
      soil = h[:soil].presence ? h[:soil].map { |k, v| "#{k}=#{Array(v).join('/')}" }.join(" ") : "soil unknown"
      [ h[:name], pin, area, "irrigation #{h[:irrigation] || 'unknown'}", "water #{h[:water_source] || 'unknown'}",
        "intensity #{h[:cropping_intensity] || 'unknown'}", soil ].compact.join("; ")
    end

    def crop_line(record)
      h = crop_hash(record)
      months = h[:planting_month] ? "planted #{h[:planting_month]}, harvest #{h[:harvest_month] || '?'}" : "months unknown"
      "#{h[:season_year]}: #{h[:crop_name]}#{h[:scientific_name] ? " (#{h[:scientific_name]})" : ''}, #{h[:role]}, #{months}, field #{h[:field_id]}"
    end
  end
end
