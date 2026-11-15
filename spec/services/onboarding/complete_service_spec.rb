require "rails_helper"

RSpec.describe Onboarding::CompleteService, type: :service do
  let(:user) { create(:user) }

  it "marks the session completed and stores the segment" do
    allow(Onboarding::SegmentClassifier).to receive(:call).with(user: user).and_return(Success(segment: "mid_mechanized"))

    result = described_class.call(user: user)

    expect(result.value).to eq(segment: "mid_mechanized")
    session = user.onboarding_session
    expect(session).to be_completed
    expect(session.completed_at).to be_present
    expect(user.farmer_profile.segment).to eq("mid_mechanized")
  end

  it "keeps the first completion time when called again" do
    first = described_class.call(user: user)
    expect(first).to be_success
    completed_at = user.onboarding_session.completed_at

    travel 1.hour do
      described_class.call(user: user)
    end

    expect(user.onboarding_session.reload.completed_at).to be_within(1.second).of(completed_at)
  end
end
