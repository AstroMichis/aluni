require "rails_helper"

RSpec.describe Field, type: :model do
  it { is_expected.to belong_to(:farm) }
  it { is_expected.to have_many(:field_crops).dependent(:destroy) }
  it { is_expected.to define_enum_for(:irrigation).with_values(unknown: 0, rainfed: 10, irrigated: 20, drip: 30, sprinkler: 40, pivot: 50, gravity: 60, other: 70).with_prefix }
  it { is_expected.to define_enum_for(:water_source).with_values(unknown: 0, rain: 10, well: 20, river_canal: 30, reservoir: 40, mixed: 50).with_prefix }

  it "keeps the pin on the globe" do
    expect(build(:field, latitude: 91)).not_to be_valid
    expect(build(:field, longitude: -181)).not_to be_valid
    expect(build(:field, latitude: -33.5, longitude: 151.2)).to be_valid
    expect(build(:field, :unlocated)).to be_valid
    expect(build(:field, :unlocated)).not_to be_located
  end

  it "keeps soil answers inside the ECOCROP classes and allows the free keys" do
    expect(build(:field, soil: { "texture" => "medium", "drainage" => "well", "ph" => 6.2, "lab_test" => true })).to be_valid
    expect(build(:field, soil: { "texture" => "sandy" })).not_to be_valid
    expect(build(:field, soil: { "problems" => %w[wet_spots compaction] })).to be_valid
    expect(build(:field, soil: { "problems" => %w[dragons] })).not_to be_valid
    expect(build(:field, soil: { "colour" => "red" })).not_to be_valid
    expect(build(:field, soil: [])).not_to be_valid
  end

  it "knows whether water is applied" do
    expect(build(:field, irrigation: :rainfed)).not_to be_uses_irrigation
    expect(build(:field, irrigation: :unknown)).not_to be_uses_irrigation
    expect(build(:field, irrigation: :drip)).to be_uses_irrigation
    expect(build(:field, irrigation: :irrigated)).to be_uses_irrigation
  end

  it "wants a positive area when given" do
    expect(build(:field, area: 0)).not_to be_valid
    expect(build(:field, area: nil)).to be_valid
  end
end
