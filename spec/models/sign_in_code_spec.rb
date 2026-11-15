require "rails_helper"

RSpec.describe SignInCode, type: :model do
  it { is_expected.to validate_presence_of(:destination) }
  it { is_expected.to define_enum_for(:channel).with_values(email: 0, sms: 10).with_prefix }

  it "is live until consumed or expired, exhausted after five attempts" do
    code = create(:sign_in_code)
    expect(code).to be_live
    expect(code).not_to be_exhausted
    expect(described_class.live).to include(code)

    code.update!(attempts: SignInCode::MAX_ATTEMPTS)
    expect(code).to be_exhausted

    expect(build(:sign_in_code, :expired)).not_to be_live
    expect(build(:sign_in_code, :verified)).not_to be_live
  end

  it "allows a resend only after the cooldown" do
    code = create(:sign_in_code)
    expect(code.resend_after).to be_between(59, 60)

    travel 61.seconds
    expect(code.resend_after).to eq(0)
  end

  it "only accepts available locales" do
    expect(build(:sign_in_code, locale: "fr")).not_to be_valid
  end
end
