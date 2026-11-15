require "rails_helper"

RSpec.describe Weather::Season do
  let(:field) { create(:field) }

  it "builds the season and the normals from the NASA POWER observation" do
    season = described_class.for(create(:field_observation, field: field, payload: power_payload(year: 2026)))

    expect(season.days.size).to eq(304)
    expect(season.totals[:heat_days]).to eq(1)
    expect(season.events.map(&:kind)).to include("heat", "heavy_rain")
    expect(season.normals[5]).to include("T2M" => 17, "PRECTOTCORR" => 3.9)
    expect(season.weekly_rain.size).to eq(44)
  end

  it "is empty without an observation or when it failed" do
    expect(described_class.for(nil)).not_to be_any
    expect(described_class.for(create(:field_observation, field: field, status: :failed))).not_to be_any
  end
end
