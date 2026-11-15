require "rails_helper"

RSpec.describe Farm, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:fields).dependent(:destroy) }

  it "normalises and validates the country code" do
    expect(build(:farm, country_code: " us ").country_code).to eq("US")
    expect(build(:farm, country_code: "").country_code).to be_nil
    expect(build(:farm, country_code: "USA")).not_to be_valid
  end

  it "orders fields by position" do
    farm = create(:farm)
    second = create(:field, farm: farm, position: 1)
    first = create(:field, farm: farm, position: 0)
    expect(farm.fields.reload).to eq([ first, second ])
  end
end
