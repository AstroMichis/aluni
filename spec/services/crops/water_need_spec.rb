require "rails_helper"

RSpec.describe Crops::WaterNeed do
  let(:observation) { build(:field_observation, payload: { "climatology" => climatology_normals, "elevation" => 491 }) }

  it "computes FAO-56 reference ET by month from the POWER normals" do
    et0 = Weather::Et0.monthly(climatology_normals, latitude: 40.95, elevation: 491)
    expect(et0[7]).to be_between(4.5, 7.0)   # midsummer, temperate
    expect(et0[1]).to be < et0[7]
  end

  it "sets a crop's season need against the effective rain" do
    need = described_class.for("zea-mays", observation: observation, latitude: 40.95)

    expect(need.days).to eq(150)
    expect(need.crop_mm).to be_between(450, 800) # FAO's range for maize
    expect(need.effective_mm).to be < need.rain_mm
    expect(need.deficit_mm).to be_positive
  end

  it "has no need for crops whose FAO-56 values were not captured, or without the normals" do
    expect(described_class.for("triticum-aestivum", observation: observation, latitude: 40.95)).to be_nil
    expect(described_class.for("zea-mays", observation: nil, latitude: 40.95)).to be_nil
  end
end
