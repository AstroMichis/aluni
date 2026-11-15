require "rails_helper"

RSpec.describe Onboarding::ResetService do
  let(:user) { create(:user) }

  it "starts the chat over and keeps the profile data and an active block" do
    profile = create(:farmer_profile, user: user, budget_level: :low)
    session = create(:onboarding_session, :completed, user: user, language: "es",
                                                       transcript: [ { "role" => "user", "text" => "hi", "at" => Time.current.iso8601 } ],
                                                       proposal: { "farm" => { "name" => "x" } }, pending_message: "again",
                                                       fallbacks_count: 2, turns_count: 9, strikes: 1, blocked_until: 2.hours.from_now, last_message_at: Time.current)

    result = described_class.call(user: user)

    expect(result).to be_success
    session.reload
    expect(session).to have_attributes(topic: "welcome", status: "active", completed_at: nil, transcript: [], proposal: {},
                                       pending_message: nil, fallbacks_count: 0, turns_count: 0, strikes: 0, last_message_at: nil, language: "es")
    expect(session.blocked_until).to be_present
    expect(profile.reload.budget_level).to eq("low")
  end
end
