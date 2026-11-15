require "rails_helper"

RSpec.describe Fields::Profile do
  subject(:profile) { described_class.current }

  it "loads every datum, source and step" do
    expect(profile.data(:farm)).not_to be_empty
    expect(profile.data(:field)).not_to be_empty
    expect(profile.steps.last.input).to eq("review")
  end

  it "points every documented source at a file in docs/data_sources" do
    profile.sources.each_value.select(&:documented?).each do |source|
      expect(Rails.root.join("docs/data_sources", source.doc)).to exist, "#{source.id}: #{source.doc}"
    end
  end

  it "reads only snapshot paths the farm_data.py output has" do
    snapshot = JSON.parse(File.read(Rails.root.join("farm_data_42.0_-93.75.json")))
    profile.data(:farm).concat(profile.data(:field)).flat_map { |datum| datum.snapshot.values }.each do |path|
      *parents, last = path.split(".")
      node = snapshot.dig(*parents)
      found = last.end_with?("*") ? node.keys.any? { |k| k.start_with?(last.delete_suffix("*")) } : node.key?(last)
      expect(found).to be(true), path
    end
  end

  it "has copy for every datum, group, feed and option in both locales" do
    %i[en es].each do |locale|
      (profile.data(:farm) + profile.data(:field)).each do |datum|
        expect(I18n.exists?("fields.data.#{datum.key}.label", locale)).to be(true), "#{locale} #{datum.key}"
        expect(I18n.exists?("fields.groups.#{datum.group}", locale)).to be(true)
        datum.feeds.each { |feed| expect(I18n.exists?("fields.feeds.#{feed}", locale)).to be(true), feed }
        datum.options.each { |option| next if datum.months # month names come from date.month_names
                              expect(I18n.exists?("fields.options.#{datum.key}.#{option}", locale)).to be(true), "#{datum.key}.#{option}" }
        # Several named values need a template to read as one sentence; one value can stand alone.
        expect(I18n.exists?("fields.data.#{datum.key}.value", locale)).to be(true), datum.key if datum.snapshot.size > 1
      end
    end
  end

  it "takes the finest scale per layer and marks data without a documented source as gaps" do
    slope = profile.fetch(:slope)
    expect(slope.scale("global")).to eq("parcel")
    expect(slope.sources_for("us").map(&:id)).to eq(%w[usgs_3dep srtm])

    expect(profile.fetch(:drainage).gap?("global")).to be(true)
    expect(profile.fetch(:drainage).gap?("us")).to be(false)
    expect(profile.gaps("global").map(&:key)).to include("country", "soil_type", "drainage")
    expect(profile.gaps("global").map(&:key)).not_to include("crop_history") # asked outside the US, by design
  end

  it "rejects a datum with an unknown source" do
    data = YAML.safe_load(File.read(described_class::PATH))
    data["data"]["farm"]["location"]["sources"] = { "global" => ["nowhere"] }
    expect { described_class.new(data, source: "inline") }.to raise_error(described_class::Invalid, /unknown source nowhere/)
  end
end
