require "rails_helper"

RSpec.describe OnboardingSession, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:topic) }
  it { is_expected.to define_enum_for(:status).with_values(active: 0, completed: 10) }

  it "starts at the welcome topic, active, with an empty transcript" do
    session = create(:onboarding_session)
    expect(session.topic).to eq("welcome")
    expect(session).to be_active
    expect(session.transcript).to eq([])
    expect(session.proposal).to eq({})
  end

  it "round-trips the transcript through JSON and stores it encrypted" do
    session = create(:onboarding_session)
    session.update!(transcript: [ { "role" => "user", "text" => "hello from the farm" } ])

    expect(session.reload.transcript).to eq([ { "role" => "user", "text" => "hello from the farm" } ])
    raw = described_class.connection.select_value("SELECT transcript FROM onboarding_sessions WHERE id = #{session.id}")
    expect(raw).not_to include("hello from the farm")
  end

  it "encrypts the pending message" do
    session = create(:onboarding_session, pending_message: "my phone is 555")
    raw = described_class.connection.select_value("SELECT pending_message FROM onboarding_sessions WHERE id = #{session.id}")
    expect(raw).not_to include("555")
    expect(session.reload.pending_message).to eq("my phone is 555")
  end

  it "is blocked only while blocked_until is in the future" do
    expect(build(:onboarding_session, blocked_until: nil)).not_to be_blocked
    expect(build(:onboarding_session, blocked_until: 1.hour.ago)).not_to be_blocked
    expect(build(:onboarding_session, blocked_until: 1.hour.from_now)).to be_blocked
  end

  it "only accepts available languages" do
    expect(build(:onboarding_session, language: "fr")).not_to be_valid
    expect(build(:onboarding_session, language: nil)).to be_valid
  end

  it "marks the user's onboarding complete" do
    session = create(:onboarding_session, :completed)
    expect(session.user.onboarding_complete?).to be(true)
    expect(create(:user).onboarding_complete?).to be(false)
  end
end
