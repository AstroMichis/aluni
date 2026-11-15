require "rails_helper"

RSpec.describe Weather::WaterStorage do
  # 2004-2009 around zero, then a long drop like central Chile's megadrought.
  let(:series) do
    (0...240).map { |i| date = Date.new(2004, 1, 15) >> i; [ date, date.year < 2010 ? 0.0 : -20.0 - ((date.year - 2010) * 0.5) ] }
  end
  let(:payload) { described_class.summarize(series) }

  it "keeps the last year against 2004-2009, the decade's trend and the lowest year" do
    expect(payload).to include("from" => "2004-01-15", "to" => "2023-12-15", "months" => 240, "recent_cm" => -26.5,
                               "lowest" => { "year" => 2023, "cm" => -26.5 }, "source" => "NASA GRACE / GRACE-FO")
    expect(payload["trend_cm_per_decade"]).to be_within(0.5).of(-5.0)
    expect(payload["years"]["2009"]).to eq(0.0)
  end

  it "calls a store more than 10 cm below 2004-2009 depleted" do
    storage = described_class.new(build(:field_observation, source: "grace", payload: payload))

    expect(storage).to be_depleted
    expect(described_class.new(nil)).not_to be_present
    expect(described_class.summarize(series.first(10))).to eq({})
  end
end
