require "rails_helper"

# Every value the onboarding chat can propose or show has a label in both
# locales, every topic has its copy, and the Gemini schema cannot drift from
# the model enums it is built from.
RSpec.describe "Onboarding labels" do
  LABEL_LOCALES = %i[en es].freeze

  # onboarding.values.<attribute>.<value>
  LABELLED_ENUMS = {
    "role" => FarmerProfile.roles, "experience" => FarmerProfile.experiences, "team" => FarmerProfile.teams,
    "units" => FarmerProfile.units, "land_tenure" => FarmerProfile.land_tenures, "budget_level" => FarmerProfile.budget_levels,
    "risk_tolerance" => FarmerProfile.risk_tolerances, "segment" => FarmerProfile.segments,
    "location_confidence" => Field.location_confidences, "location_source" => Field.location_sources,
    "area_unit" => Field.area_units, "irrigation" => Field.irrigations, "water_source" => Field.water_sources,
    "cropping_intensity" => Field.cropping_intensities, "source" => FieldCrop.sources, "crop_role" => FieldCrop.roles
  }.freeze
  LABELLED_LISTS = {
    "goals" => FarmerProfile::GOALS, "equipment" => FarmerProfile::EQUIPMENT, "livestock" => FarmerProfile::LIVESTOCK,
    "market_channels" => FarmerProfile::MARKET_CHANNELS, "practices" => FarmerProfile::PRACTICES
  }.merge(Field::SOIL).freeze

  def label!(key, locale)
    I18n.t!(key, locale: locale)
  rescue I18n::MissingTranslationData
    key
  end

  def missing(keys)
    LABEL_LOCALES.flat_map { |locale| keys.select { |key| label!(key, locale) == key }.map { |key| "#{locale}: #{key}" } }
  end

  it "labels every enum value the chat can propose, in both locales" do
    keys = LABELLED_ENUMS.flat_map do |attribute, mapping|
      (mapping.keys - [ "unknown" ]).map { |value| "onboarding.values.#{attribute}.#{value}" }
    end
    expect(missing(keys)).to be_empty
  end

  it "labels every allowlist slug, in both locales" do
    keys = LABELLED_LISTS.flat_map { |attribute, values| values.map { |value| "onboarding.values.#{attribute}.#{value}" } }
    expect(missing(keys)).to be_empty
  end

  it "labels every applied key the Saved toast can show" do
    profile = Onboarding::Allowlist::PROFILE_ENUMS.keys + Onboarding::Allowlist::PROFILE_LISTS.keys + Onboarding::Allowlist::PROFILE_SCALARS.keys
    field = Onboarding::Allowlist::FIELD_ENUMS.keys + Onboarding::Allowlist::FIELD_SCALARS.keys + %w[latitude]
    soil = Onboarding::Allowlist::SOIL_ENUMS.keys + Onboarding::Allowlist::SOIL_SCALARS.keys + %w[problems]
    keys = profile.map { |k| "onboarding.field_labels.profile.#{k}" } +
      Onboarding::Allowlist::FARM_SCALARS.keys.map { |k| "onboarding.field_labels.farm.#{k}" } +
      field.map { |k| "onboarding.field_labels.field.#{k}" } +
      soil.map { |k| "onboarding.field_labels.field.soil.#{k}" } +
      %w[onboarding.field_labels.crops]
    expect(missing(keys)).to be_empty
  end

  it "gives every topic a title, a transition and continuation lines" do
    Onboarding::Topics.keys.each do |topic|
      LABEL_LOCALES.each do |locale|
        expect(I18n.t!("onboarding.topics.#{topic}", locale: locale)).to be_present
        expect(I18n.t!("onboarding.transitions.#{topic}", locale: locale)).to be_present
        expect(I18n.t!("onboarding.continuations.#{topic}", locale: locale)).to be_an(Array).and all(be_present)
      end
    end
  end

  # Schema words are symbols, attribute names are strings; look up either way.
  def at(hash, *path)
    path.reduce(hash) { |node, key| node && (node[key.to_sym] || node[key.to_s]) }
  end

  it "builds the Gemini schema enums from the models" do
    props = at(Onboarding::DraftReplyService::RESPONSE_SCHEMA, :properties, :updates, :properties)
    expect(at(props, :profile, :properties, :role, :enum)).to match_array(FarmerProfile.roles.keys - [ "unknown" ])
    expect(at(props, :profile, :properties, :goals, :items, :enum)).to match_array(FarmerProfile::GOALS)
    expect(at(props, :field, :properties, :irrigation, :enum)).to match_array(Field.irrigations.keys - [ "unknown" ])
    expect(at(props, :field, :properties, :soil_texture, :enum)).to match_array(Field::SOIL["texture"])
    expect(at(props, :crops, :items, :properties, :role, :enum)).to match_array(FieldCrop.roles.keys)
  end
end
