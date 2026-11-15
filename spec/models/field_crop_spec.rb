require "rails_helper"

RSpec.describe FieldCrop, type: :model do
  it { is_expected.to belong_to(:field) }
  it { is_expected.to validate_presence_of(:crop_name) }
  it { is_expected.to define_enum_for(:role).with_values(main: 0, second: 10, cover: 20, intercrop: 30).with_prefix }

  it "slugs the scientific name, or the common name without one" do
    expect(create(:field_crop).crop_key).to eq("zea-mays")
    expect(create(:field_crop, crop_name: "Papa criolla", scientific_name: nil, season_year: 2024).crop_key).to eq("papa-criolla")
  end

  it "keeps months in 1..12 and the year plausible" do
    expect(build(:field_crop, planting_month: 13)).not_to be_valid
    expect(build(:field_crop, harvest_month: 0)).not_to be_valid
    expect(build(:field_crop, planting_month: nil, harvest_month: nil)).to be_valid
    expect(build(:field_crop, season_year: 1800)).not_to be_valid
  end

  it "allows one crop per role per season on a field" do
    first = create(:field_crop)
    expect(build(:field_crop, field: first.field, season_year: first.season_year, role: :main)).not_to be_valid
    expect(build(:field_crop, field: first.field, season_year: first.season_year, role: :cover, crop_name: "Rye")).to be_valid
  end
end
