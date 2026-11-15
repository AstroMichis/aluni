require "rails_helper"

RSpec.describe Weather::RainExtremes do
  # Two years of 1 mm a day, with a 30 mm day every July and a 60 mm one in July 2024.
  let(:daily) do
    (Date.new(2024, 1, 1)..Date.new(2025, 12, 31)).to_h { |d| [ d.strftime("%Y%m%d"), 1.0 ] }.merge(
      "20240710" => 60.0, "20240711" => 30.0, "20250712" => 30.0, "20250301" => nil
    ).merge((Date.new(2025, 2, 1)..Date.new(2025, 2, 20)).to_h { |d| [ d.strftime("%Y%m%d"), 0.0 ] })
  end
  let(:payload) { described_class.summarize(daily) }

  it "counts heavy and extreme days per year and per month" do
    expect(payload).to include("from" => "2024-01-01", "to" => "2025-12-31", "years" => 2,
                               "heavy_days_per_year" => 1.5, "extreme_days_per_year" => 0.5,
                               "wettest" => { "date" => "2024-07-10", "mm" => 60.0 }, "source" => "NASA GPM IMERG")
    july = payload["months"].find { |m| m["month"] == 7 }
    expect(july).to include("heavy_days" => 1.5, "extreme_days" => 0.5, "max_mm" => 60.0)
    expect(payload["months"].find { |m| m["month"] == 1 }).to include("rain_mm" => 31, "heavy_days" => 0.0)
  end

  it "keeps the longest dry spell of each year" do
    expect(payload["dry_spell"]).to eq("median_days" => 20, "max_days" => 20) # 2024 has none: [0, 20]
  end

  it "reads the storm-prone months back from the observation" do
    observation = build(:field_observation, source: "gpm_imerg", payload: payload)
    rain = described_class.new(observation)

    expect(rain).to be_present
    expect(rain.stormy_months.map(&:month)).to eq([ 7 ])
    expect(rain).not_to be_stormy_field # half a 50 mm day a year
    expect(described_class.new(nil)).not_to be_present
  end

  it "is empty without values and covers the last 20 full years" do
    expect(described_class.summarize("20250101" => nil)).to eq({})
    expect(described_class.window(today: Date.new(2026, 11, 15))).to eq([ Date.new(2006, 1, 1), Date.new(2025, 12, 31) ])
  end
end
