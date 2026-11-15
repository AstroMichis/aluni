require "rails_helper"

RSpec.describe Onboarding::SegmentClassifier do
  let(:user) { create(:user) }

  def profile(**attrs)
    create(:farmer_profile, :blank, user: user, **attrs)
  end

  def field(area:, area_unit: :hectares)
    create(:field, farm: create(:farm, user: user), area: area, area_unit: area_unit)
  end

  it "names a smallholder: under two hectares, family, low budget, nothing sold beyond the local market" do
    profile(team: :family, budget_level: :low, market_channels: %w[own_use local_market])
    field(area: 1.5)

    expect(described_class.call(user: user).value).to eq(segment: "smallholder_subsistence")
  end

  it "converts acres before comparing" do
    profile(team: :solo, budget_level: :low, market_channels: %w[own_use])
    field(area: 4, area_unit: :acres)

    expect(described_class.call(user: user).value[:segment]).to eq("smallholder_subsistence")
  end

  it "names a small commercial farm: under twenty hectares with a selling channel" do
    profile(team: :family, budget_level: :low, market_channels: %w[local_market])
    field(area: 8)

    expect(described_class.call(user: user).value[:segment]).to eq("small_commercial")
  end

  it "names a mid mechanized farm by area or by tractor plus planter and a team" do
    profile(team: :family)
    field(area: 50)
    expect(described_class.call(user: user).value[:segment]).to eq("mid_mechanized")

    user.farmer_profile.update!(team: :small_team, equipment: %w[tractor planter])
    user.farms.first.fields.first.update!(area: 10)
    expect(described_class.call(user: user).value[:segment]).to eq("mid_mechanized")
  end

  it "names a large commercial farm by area or by a crew selling in bulk" do
    profile(team: :solo)
    field(area: 300)
    expect(described_class.call(user: user).value[:segment]).to eq("large_commercial")

    user.farmer_profile.update!(team: :crew, market_channels: %w[wholesale])
    user.farms.first.fields.first.update!(area: 5)
    expect(described_class.call(user: user).value[:segment]).to eq("large_commercial")
  end

  it "is unknown when the facts are missing" do
    profile
    expect(described_class.call(user: user).value[:segment]).to eq("unknown")
  end
end
