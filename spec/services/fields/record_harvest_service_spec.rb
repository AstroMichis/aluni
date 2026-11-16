require "rails_helper"

RSpec.describe Fields::RecordHarvestService do
  let(:user) { create(:user) }
  let(:field) { create_farm_for(user) }
  let(:crop) { field.field_crops.where(role: :main).where(season_year: ..Date.current.year).first }

  it "saves the yield, price and cost in the farmer's units, with a comma as the decimal mark" do
    result = described_class.call(user: user, crop_id: crop.id, values: { "yield_amount" => "180", "yield_unit" => "bu", "area_basis" => "ac",
                                                                          "price" => "4,25", "cost" => "", "currency" => "USD" })
    expect(result).to be_success
    expect(crop.reload.price).to eq(4.25)
    expect(crop.margin_per_ha).to be_within(0.01).of(180 * 4.25 * FieldCrop::ACRES_PER_HECTARE)
  end

  it "refuses text that is not a number, and a yield without its unit" do
    expect(described_class.call(user: user, crop_id: crop.id, values: { "yield_amount" => "lots" })).to be_failure
    expect(described_class.call(user: user, crop_id: crop.id, values: { "yield_amount" => "3" })).to be_failure
  end

  it "does not reach another farmer's crop" do
    expect(described_class.call(user: user, crop_id: create(:field_crop).id, values: {})).to be_failure
  end
end
