require "rails_helper"

RSpec.describe Fields::CreateFieldService do
  let(:user) { create(:user) }
  let!(:farm) { create(:farm, user: user) }

  it "creates the field with its crops and asks the data sources about the pin" do
    result = nil
    expect {
      result = described_class.call(user: user, attributes: { name: "Road field", latitude: "9.93", longitude: "-84.08", area: "3", area_unit: "hectares", irrigation: "drip" },
                                    crop: "Frijol", planting_month: "5", harvest_month: "8", history: { (Date.current.year - 1).to_s => "Maíz" })
    }.to have_enqueued_job(Fields::FetchObservationsJob)

    field = result.value
    expect(field).to have_attributes(name: "Road field", irrigation: "drip", location_confidence: "confirmed", farm: farm)
    expect(field.field_crops.pluck(:season_year, :crop_name, :scientific_name)).to contain_exactly(
      [ Date.current.year, "Frijol", "Phaseolus vulgaris" ], [ Date.current.year - 1, "Maíz", "Zea mays" ])
  end

  it "needs a valid pin" do
    expect(described_class.call(user: user, attributes: { name: "No pin" })).to be_failure
    expect(described_class.call(user: user, attributes: { latitude: "200", longitude: "0" })).to be_failure
  end
end
