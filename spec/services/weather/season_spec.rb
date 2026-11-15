require "rails_helper"

RSpec.describe Weather::Season do
  subject(:season) { described_class.load }

  it "reads the daily NASA POWER rows and matches farm_data.py's summary" do
    summary = JSON.parse(File.read(Rails.root.join("farm_data_42.0_-93.75.json")))["climate_summary"]

    expect(season.days.size).to eq(304)
    expect(season.totals).to include(rain: summary["precip_total_mm"], frost_days: summary["frost_days"], heat_days: summary["heat_stress_days_gt32c"])
  end

  it "sums rain by week and month, and finds the frost-free stretch and the season's events" do
    expect(season.weekly_rain.size).to eq(44)
    expect(season.monthly.sum { |m| m[:rain] }).to be_within(0.5).of(854.3)
    expect(season.frost_free[:last_spring]).to eq(Date.new(2025, 4, 8))
    expect(season.events.map(&:kind).uniq).to contain_exactly("frost", "heat", "heavy_rain", "dry_spell")
    expect(season.events.select { |e| e.kind == "dry_spell" }).to all(have_attributes(value: be >= 10))
  end
end
