require "rails_helper"

RSpec.describe Fields::VegetationNormal do
  # MOD13Q1 at Buin, Chile, from AppEEARS (2000-12 to 2026-09; NDVI and pixel reliability kept).
  let(:payload) { described_class.summarize(data_source_fixture("modis_mod13q1_buin.csv")) }

  it "keeps the median NDVI of each month and the last 12 months against it" do
    expect(payload).to include("from" => "2000-12-18", "to" => "2026-09-14", "years" => 26, "peak_month" => 10, "low_month" => 5,
                               "source" => "NASA MODIS (Terra)")
    expect(payload["normal"].values).to all(be_between(0.15, 0.3))
    expect(payload["recent"].last).to include("month" => "2026-09", "normal" => payload["normal"]["9"])
    expect(payload["recent"].last["anomaly"]).to be_within(0.001).of(payload["recent"].last["ndvi"] - payload["normal"]["9"])
    expect(payload["below"]).to eq([]) # nothing 0.1 under its normal this year
  end

  it "reads the normal back for a month and flags months well below it" do
    normal = described_class.new(build(:field_observation, source: "modis", payload: payload.merge("below" => [ "2026-09" ])))

    expect(normal.normal_for("2026-10")).to eq(payload["normal"]["10"])
    expect(normal.below).to eq([ "2026-09" ])
    expect(described_class.new(nil)).not_to be_present
  end
end
