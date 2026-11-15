module Fields
  # Writes what the field finder collected: the main field's pin (confirmed), its
  # place label, area and irrigation, the farm's country and region, the crop on
  # the field this season, the profile's units from the country, and closes the
  # onboarding so /app shows the recap instead of asking again. Reuses
  # Onboarding::EnsureProfileService for the rows and Onboarding::CompleteService
  # for the closing; idempotent (a second call updates the same rows).
  #
  # `attributes` is the string-keyed hash .coerce produces from the finder's flat
  # inputs (RegistrationsController parks it in the session during the passkey
  # ceremony; App::FieldsController builds it from params). A crop without a
  # scientific name is normalised here (Crops::NormalizeService), so the finder
  # never needs a round trip for it.
  class SaveSetupService < ApplicationService
    IMPERIAL_COUNTRIES = %w[US LR MM].freeze
    SCALARS = {
      "latitude" => :latitude, "longitude" => :longitude, "place_label" => :text, "country_code" => :country_code,
      "admin_area" => :text, "crop_name" => :text, "scientific_name" => :text, "area" => :positive_number
    }.freeze
    ENUMS = {
      "location_source" => Field.location_sources.keys - [ "unknown" ],
      "irrigation" => Field.irrigations.keys - [ "unknown" ],
      "area_unit" => Field.area_units.keys
    }.freeze
    KEYS = (SCALARS.keys + ENUMS.keys).freeze

    # The finder's flat keys (strings or numbers, as a form or a JSON body sends
    # them) into clean attributes; nil when there is no pin.
    def self.coerce(raw)
      source = (raw || {}).to_h.transform_keys(&:to_s)
      attrs = {}
      SCALARS.each do |key, kind|
        value = Onboarding::Allowlist.coerce(source[key], kind)
        attrs[key] = value unless value.nil?
      end
      ENUMS.each do |key, allowed|
        value = source[key].to_s
        attrs[key] = value if allowed.include?(value)
      end
      attrs if attrs["latitude"] && attrs["longitude"]
    end

    def initialize(user:, attributes:)
      @user = user
      @attributes = attributes
    end

    def call
      attrs = step validate
      rows = step Onboarding::EnsureProfileService.call(user: @user)
      crop = crop_for(attrs)
      completion = nil

      ActiveRecord::Base.transaction do
        write_field(rows[:field], attrs)
        write_farm(rows[:farm], attrs)
        write_crop(rows[:field], crop) if crop
        write_units(rows[:profile], attrs)
        completion = Onboarding::CompleteService.call(user: @user)
        raise ActiveRecord::Rollback if completion.failure?
      end

      step completion
      Success(field: rows[:field].reload)
    rescue ActiveRecord::RecordInvalid => e
      Failure(code: :invalid, messages: e.record.errors.full_messages)
    end

    private

    def validate
      attrs = self.class.coerce(@attributes)
      return Failure(code: :invalid, messages: [ I18n.t("finder.errors.pin_required") ]) if attrs.nil?

      Success(attrs)
    end

    def write_field(field, attrs)
      changes = {
        latitude: attrs["latitude"], longitude: attrs["longitude"], location_confidence: "confirmed",
        location_source: attrs["location_source"] || "map", place_label: attrs["place_label"]
      }
      changes[:area] = attrs["area"] if attrs.key?("area")
      changes[:area_unit] = attrs["area_unit"] if attrs.key?("area_unit")
      changes[:irrigation] = attrs["irrigation"] if attrs.key?("irrigation")
      field.update!(changes)
    end

    def write_farm(farm, attrs)
      changes = attrs.slice("country_code", "admin_area")
      farm.update!(changes) if changes.any?
    end

    # The crop on the field this season, as the farmer said it.
    def write_crop(field, crop)
      row = field.field_crops.find_or_initialize_by(season_year: Date.current.year, role: "main")
      row.assign_attributes(crop_name: crop[:crop_name], scientific_name: crop[:scientific_name], source: "farmer")
      row.save!
    end

    # Imperial for the three countries that farm in acres, metric elsewhere; left
    # alone when the country is not known.
    def write_units(profile, attrs)
      country = attrs["country_code"]
      return unless country

      profile.update!(units: IMPERIAL_COUNTRIES.include?(country) ? "imperial" : "metric")
    end

    def crop_for(attrs)
      name = attrs["crop_name"]
      return nil if name.blank?
      return { crop_name: name, scientific_name: attrs["scientific_name"] } if attrs["scientific_name"].present?

      case Crops::NormalizeService.call(text: name, locale: @user.locale)
      in Result::Success({ crop_name:, scientific_name: }) then { crop_name: crop_name, scientific_name: scientific_name }
      else { crop_name: name, scientific_name: nil }
      end
    end
  end
end
