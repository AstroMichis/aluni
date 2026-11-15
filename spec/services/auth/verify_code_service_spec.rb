require "rails_helper"

RSpec.describe Auth::VerifyCodeService do
  let(:record) { create(:sign_in_code, code: "123456", destination: "ana@example.com") }

  it "proves the code once, with spaces allowed, and reports a new address" do
    result = described_class.call(sign_in_code: record, code: "123 456", ip: "1.1.1.1")

    expect(result).to be_success
    expect(result.value).to include(user: nil, sign_in_code: record)
    expect(record.reload).to be_verified
    expect(record).not_to be_live
    expect(record.attempts).to eq(1)

    expect(described_class.call(sign_in_code: record, code: "123456", ip: "1.1.1.1").error).to include(code: :expired)
  end

  it "signs an existing account in and marks its address verified" do
    user = create(:user, :with_email, email_address: "ana@example.com")

    result = described_class.call(sign_in_code: record, code: "123456", ip: "1.1.1.1")

    expect(result.value[:user]).to eq(user)
    expect(user.reload.email_verified_at).to be_present
  end

  it "counts wrong attempts and gives up after five" do
    4.times do |i|
      result = described_class.call(sign_in_code: record, code: "000000", ip: "1.1.1.1")
      expect(result.error).to include(code: :wrong, attempts_left: 4 - i)
    end
    expect(described_class.call(sign_in_code: record, code: "000000", ip: "1.1.1.1").error).to include(code: :expired)
    expect(described_class.call(sign_in_code: record, code: "123456", ip: "1.1.1.1").error).to include(code: :expired)
  end

  it "refuses expired, missing and sign-ups-closed cases" do
    expect(described_class.call(sign_in_code: create(:sign_in_code, :expired), code: "123456", ip: "1.1.1.1").error).to include(code: :expired)
    expect(described_class.call(sign_in_code: nil, code: "123456", ip: "1.1.1.1").error).to include(code: :expired)

    Rails.configuration.x.signups.enabled = false
    expect(described_class.call(sign_in_code: record, code: "123456", ip: "1.1.1.1").error).to include(code: :signups_closed)
  ensure
    Rails.configuration.x.signups.enabled = true
  end
end
