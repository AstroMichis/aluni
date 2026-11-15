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

  it "moves the default planting month six months south of the tropics" do
    expect(described_class.default_month(4, 40.95)).to eq(4)   # maize row: April
    expect(described_class.default_month(4, -33.8)).to eq(10)  # central Chile: October
    expect(described_class.default_month(9, -33.8)).to eq(3)
    expect(described_class.default_month(4, -5.0)).to eq(4)    # near the equator the row stays
    expect(described_class.for("zea-mays", observation: observation, latitude: -33.8).planting_month).to eq(10)
  end

  it "keeps the farmer's own planting month anywhere" do
    expect(described_class.for("zea-mays", observation: observation, latitude: -33.8, planting_month: 11).planting_month).to eq(11)
  end

  it "takes the rain from IMERG when the field has it, with the scenario's rain change" do
    months = (1..12).map { |m| { "month" => m, "rain_mm" => 100, "heavy_days" => 0.5 } }
    imerg = build(:field_observation, source: "gpm_imerg", payload: { "years" => 20, "months" => months })

    power = described_class.for("zea-mays", observation: observation, latitude: 40.95)
    wet = described_class.for("zea-mays", observation: observation, latitude: 40.95, imerg: imerg)
    drier = described_class.for("zea-mays", observation: observation, latitude: 40.95, imerg: imerg, scenario: Weather::Scenario.find("warm2_dry"))

    expect([ power.rain_source, wet.rain_source ]).to eq(%w[power imerg])
    expect(wet.rain_mm).to be_within(5).of(100 * 150 / 30.4) # about 100 mm a month over 150 days
    expect(drier.rain_mm).to be_within(2).of(wet.rain_mm * 0.8)
    expect(wet.crop_mm).to eq(power.crop_mm) # the crop's demand does not depend on the rain source
  end

  it "plants in the region's calendar month, after the farmer's own and before the FAO-56 row" do
    iowa = { country_code: "US", admin_area: "Iowa" }

    expect(described_class.for("zea-mays", observation: observation, latitude: 42.0, place: iowa).planting_month).to eq(5)
    expect(described_class.for("zea-mays", observation: observation, latitude: 42.0, place: { country_code: "US", admin_area: "Texas" }).planting_month).to eq(4)
    expect(described_class.for("zea-mays", observation: observation, latitude: 42.0, place: iowa, planting_month: 4).planting_month).to eq(4)
  end

  it "covers the catalog crops whose FAO-56 rows were captured" do
    %w[sorghum-bicolor triticum-aestivum phaseolus-vulgaris solanum-tuberosum gossypium-hirsutum].each do |crop|
      need = described_class.for(crop, observation: observation, latitude: 40.95)
      expect(need&.crop_mm).to be_positive, crop
    end
  end

  it "has no need for crops whose FAO-56 values were not captured, or without the normals" do
    expect(described_class.for("medicago-sativa", observation: observation, latitude: 40.95)).to be_nil
    expect(described_class.for("zea-mays", observation: nil, latitude: 40.95)).to be_nil
  end
end
