require "rails_helper"

RSpec.describe User, type: :model do
  it { is_expected.to have_many(:sessions).dependent(:destroy) }
  it { is_expected.to have_many(:passkeys).dependent(:destroy) }
  it { is_expected.to have_one(:farmer_profile).dependent(:destroy) }
  it { is_expected.to have_one(:onboarding_session).dependent(:destroy) }
  it { is_expected.to have_many(:farms).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:display_name) }
  it { is_expected.to validate_length_of(:display_name).is_at_most(User::NAME_MAX) }

  it "mints a WebAuthn user handle on create" do
    user = create(:user)
    expect(user.webauthn_id).to be_present
    expect(WebAuthn.standard_encoder.decode(user.webauthn_id).bytesize).to eq(64)
  end

  it "normalises a blank email to nil and downcases the rest" do
    expect(build(:user, email_address: "  ").email_address).to be_nil
    expect(build(:user, email_address: " Ada@Example.COM ").email_address).to eq("ada@example.com")
  end

  it "only accepts available locales" do
    expect(build(:user, locale: "fr")).not_to be_valid
    expect(build(:user, locale: "es")).to be_valid
  end
end
