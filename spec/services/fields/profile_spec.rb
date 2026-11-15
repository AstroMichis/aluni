require "rails_helper"

RSpec.describe Fields::Profile do
  subject(:profile) { described_class.current }

  let(:data) { profile.data(:farm) + profile.data(:field) }

  it "loads every datum, source and step" do
    expect(profile.data(:farm)).not_to be_empty
    expect(profile.steps.map(&:input)).to eq(%w[pin details crop history review])
  end

  it "points every documented source at a file in docs/data_sources" do
    profile.sources.each_value.select(&:documented?).each do |source|
      expect(Rails.root.join("docs/data_sources", source.doc)).to exist, "#{source.id}: #{source.doc}"
    end
  end

  it "takes answer options from the onboarding allowlist, so the chat and the menu share them" do
    expect(profile.fetch(:irrigation).options).to eq(Onboarding::Allowlist::FIELD_ENUMS["irrigation"])
    expect(profile.fetch(:goals).options).to eq(FarmerProfile::GOALS)
    expect(profile.fetch(:soil_texture).options).to eq(Field::SOIL["texture"])
    expect(profile.fetch(:planting_month).options).to eq(("1".."12").to_a)
  end

  it "maps every observation source to a registry source and every FieldObservation source is covered" do
    expect(profile.observation_sources.keys).to match_array(FieldObservation::SOURCES)
  end

  it "has copy for every datum, group and feed in both locales, and a template for composite values" do
    %i[en es].each do |locale|
      data.each do |datum|
        expect(I18n.exists?("app.fields.data.#{datum.key}.label", locale)).to be(true), "#{locale} #{datum.key}"
        expect(I18n.exists?("app.fields.groups.#{datum.group}", locale)).to be(true), "#{locale} group #{datum.group}"
        datum.feeds.each { |feed| expect(I18n.exists?("app.fields.feeds.#{feed}", locale)).to be(true), feed }
        expect(I18n.exists?("app.fields.data.#{datum.key}.value", locale)).to be(true), datum.key if datum.observation.size > 1
        next if datum.months

        datum.options.each { |option| expect(I18n.exists?("onboarding.values.#{datum.values_attr}.#{option}", locale)).to be(true), "#{datum.key}.#{option}" }
      end
    end
  end

  it "knows what each layer can fill and what stays a gap" do
    slope = profile.fetch(:slope)
    expect(slope.sources_for("us").map(&:id)).to eq(%w[usgs_3dep srtm])
    expect(slope.gap?("us")).to be(false)
    expect(slope.gap?("global")).to be(false) # NASADEM fills it outside the US
    expect(profile.fetch(:soil_series).gap?("global")).to be(true) # no global soil survey yet
    expect(profile.fetch(:soil_texture).origin("global")).to eq("ask")
    expect(profile.fetch(:soil_texture).origin("us")).to eq("confirm")
  end

  it "rejects a column that is not a model path and an unknown source" do
    raw = YAML.safe_load(File.read(described_class::PATH))
    raw["data"]["farm"]["role"]["column"] = "session.role"
    expect { described_class.new(raw, source: "inline") }.to raise_error(described_class::Invalid, /not a model path/)

    raw = YAML.safe_load(File.read(described_class::PATH))
    raw["data"]["field"]["slope"]["sources"] = { "global" => [ "nowhere" ] }
    expect { described_class.new(raw, source: "inline") }.to raise_error(described_class::Invalid, /unknown source nowhere/)
  end
end
