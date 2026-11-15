require "rails_helper"

RSpec.describe Onboarding::EnsureProfileService do
  let(:user) { create(:user, locale: "es") }

  it "creates the profile, one farm with one field, and the session once" do
    result = described_class.call(user: user)

    expect(result).to be_success
    expect(result.value[:profile]).to eq(user.reload.farmer_profile)
    expect(result.value[:field]).to eq(user.farms.first.fields.first)
    expect(result.value[:session].language).to eq("es")

    again = described_class.call(user: user)
    expect(again.value[:field]).to eq(result.value[:field])
    expect(user.farms.count).to eq(1)
    expect(Field.where(farm: user.farms).count).to eq(1)
    expect(OnboardingSession.where(user: user).count).to eq(1)
  end

  it "keeps rows that already exist" do
    session = create(:onboarding_session, user: user, topic: "crops")
    result = described_class.call(user: user)
    expect(result.value[:session]).to eq(session)
    expect(session.reload.topic).to eq("crops")
  end
end
