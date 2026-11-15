require "rails_helper"

RSpec.describe Onboarding::SkipTopicService do
  let(:user) { create(:user) }

  it "advances to the next topic and leaves the transition as Aluni's turn" do
    session = Onboarding::EnsureProfileService.call(user: user).value[:session]

    result = described_class.call(user: user)

    expect(result.value).to eq(topic: "location", transition: I18n.t("onboarding.transitions.location", locale: :en), completed: false)
    expect(session.reload.topic).to eq("location")
    expect(session.transcript.last).to include("role" => "model", "text" => I18n.t("onboarding.transitions.location", locale: :en))
    expect(session.proposal).to eq({})
  end

  it "speaks the session's language unless a locale is given" do
    create(:onboarding_session, user: user, topic: "land", language: "es")

    expect(described_class.call(user: user).value[:transition]).to eq(I18n.t("onboarding.transitions.crops", locale: :es))
    expect(described_class.call(user: user, locale: "en").value[:transition]).to eq(I18n.t("onboarding.transitions.soil", locale: :en))
  end

  it "completes the onboarding on the last topic" do
    session = create(:onboarding_session, user: user, topic: "summary")

    result = described_class.call(user: user)

    expect(result.value).to eq(topic: "summary", transition: nil, completed: true)
    expect(session.reload).to be_completed
    expect(user.farmer_profile.segment).to eq("unknown")
  end
end
