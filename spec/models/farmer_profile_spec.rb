require "rails_helper"

RSpec.describe FarmerProfile, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to define_enum_for(:role).with_values(unknown: 0, owner: 10, manager: 20, worker: 30, advisor: 40).with_prefix }
  it { is_expected.to define_enum_for(:segment).with_values(unknown: 0, smallholder_subsistence: 10, small_commercial: 20, mid_mechanized: 30, large_commercial: 40).with_prefix }
  it { is_expected.to define_enum_for(:budget_level).with_values(unknown: 0, low: 10, high: 20).with_prefix }

  it "starts unknown everywhere with empty lists" do
    profile = create(:farmer_profile, :blank)
    expect(profile).to be_role_unknown.and be_segment_unknown
    expect(profile.goals).to eq([])
    expect(profile.practices).to eq([])
  end

  it "keeps the slug lists inside their allowlists" do
    expect(build(:farmer_profile, goals: %w[rotation yield])).to be_valid
    expect(build(:farmer_profile, goals: %w[rotation moon_base])).not_to be_valid
    expect(build(:farmer_profile, goals: %w[rotation rotation])).not_to be_valid
    expect(build(:farmer_profile, goals: "rotation")).not_to be_valid
    expect(build(:farmer_profile, equipment: %w[tractor drone])).to be_valid
    expect(build(:farmer_profile, market_channels: %w[ebay])).not_to be_valid
  end

  it "wants a positive team size when given" do
    expect(build(:farmer_profile, team_size: 0)).not_to be_valid
    expect(build(:farmer_profile, team_size: 4)).to be_valid
    expect(build(:farmer_profile, team_size: nil)).to be_valid
  end
end
