require "rails_helper"

RSpec.describe Weather::ScoutWindows do
  def season_at(mean, from: Date.new(2025, 5, 1), to: Date.new(2025, 9, 30))
    days = (from..to).map { |d| Weather::Season::Day.new(date: d, tmin: mean - 5, tmean: mean, tmax: mean + 5, rain: 0, wetness: 0.4) }
    Weather::Season.new(days)
  end

  it "flags tar spot on corn only inside 15 June to 15 September, once the 30-day mean sits in 18-23 °C" do
    window = described_class.for(season_at(20), %w[zea-mays]).tar_spot

    expect(window.first).to eq(Date.new(2025, 6, 15))
    expect(window.last).to eq(Date.new(2025, 9, 15))
    expect(window.favourable_days).to eq(93)
    expect(window.active).to be(false)
  end

  it "says nothing when the month is too hot, or when no corn grows" do
    expect(described_class.for(season_at(26), %w[zea-mays]).tar_spot).to be_nil
    scout = described_class.for(season_at(20), %w[glycine-max])
    expect(scout.tar_spot).to be_nil
    expect(scout.armyworm).to be_nil
    expect(scout.unrun).to eq(%w[soybean_rust])
  end

  it "counts fall armyworm degree-days above 12.57 °C from May, 391 a generation" do
    worm = described_class.for(season_at(20), %w[zea-mays]).armyworm
    expect(worm.degree_days).to eq(((20 - 12.57) * 153).round)
    expect(worm.generations).to eq((worm.degree_days / 391.0).round(1))
  end

  it "reproduces the Ames worked example's armyworm degree-days (1402 in 2025)" do
    scout = described_class.for(ames_season, %w[zea-mays])
    expect(scout.armyworm.degree_days).to eq(1402)
    expect(scout.tar_spot.favourable_days).to eq(LandingHelper::SAMPLE[:tar_spot_days])
    expect(scout.events.map(&:kind).uniq).to eq(%w[scout])
  end
end
