require "rails_helper"

RSpec.describe Weather::SoilMoisture do
  # A year of SPL4SMGP at Buin, Chile, from AppEEARS (one 01:30 reading a day of the 3-hourly file).
  let(:csv) { data_source_fixture("smap_l4_buin.csv") }
  let(:payload) { described_class.summarize(csv) }

  it "keeps one row per month, the latest reading and the dry and wet months" do
    expect(payload).to include("from" => "2025-11-01", "to" => "2026-10-31", "source" => "NASA SMAP L4",
                               "dry_months" => [ "2026-06" ], "wet_months" => %w[2026-08 2026-09 2026-10])
    expect(payload["months"].size).to eq(12)
    expect(payload["latest"]).to include("date" => "2026-10-31")
    expect(payload["months"].find { |m| m["month"] == "2026-03" }["rootzone"]).to be < 0.2 # the dry end of summer
  end

  it "leaves the percentile unknown where SMAP fills it (-9999 in the driest summer months)" do
    summer = payload["months"].select { |m| m["month"].between?("2026-01", "2026-03") }
    expect(summer.map { |m| m["pctl"] }).to all(be_nil)
    expect(described_class.new(build(:field_observation, source: "smap", payload: payload)).dry_months.map(&:month)).to eq([ "2026-06" ])
  end

  it "is empty without the moisture column and covers the last 12 full months" do
    expect(described_class.summarize("ID,Date\nx,2026-01-01\n")).to eq({})
    expect(described_class.window(today: Date.new(2026, 11, 15))).to eq([ Date.new(2025, 11, 1), Date.new(2026, 10, 31) ])
  end
end
