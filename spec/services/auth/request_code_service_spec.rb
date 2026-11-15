require "rails_helper"

RSpec.describe Auth::RequestCodeService do
  before { ActionMailer::Base.deliveries.clear }

  def code_in(mail) = mail.text_part.decoded[/\b(\d{3}) (\d{3})\b/].delete(" ")

  it "stores a hashed code, mails it with the link, and parks the sign-up details" do
    result = described_class.call(destination: " Ana@Example.com ", locale: "es", ip: "1.2.3.4",
                                  pending: { "display_name" => "Ana", "locale" => "es", "field" => { "latitude" => 9.9, "longitude" => -84.0 }, "junk" => 1 })

    expect(result).to be_success
    record = result.value[:sign_in_code]
    expect(record.destination).to eq("ana@example.com")
    expect(record.locale).to eq("es")
    expect(record.pending).to eq("display_name" => "Ana", "locale" => "es", "field" => { "latitude" => 9.9, "longitude" => -84.0 })
    expect(record.expires_at).to be_within(5.seconds).of(SignInCode::TTL.from_now)
    expect(result.value[:resend_after]).to eq(60)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ "ana@example.com" ])
    expect(Auth::Codes.match?(record, code_in(mail))).to be(true)
    expect(record.code_digest).not_to include(code_in(mail))
    token = mail.text_part.decoded[/token=([^\s&]+)/, 1]
    expect(Auth::LinkToken.read(CGI.unescape(token))).to include("id" => record.id)
  end

  it "supersedes earlier live codes for the same address" do
    first = described_class.call(destination: "ana@example.com", locale: "en", ip: "1.1.1.1").value[:sign_in_code]
    described_class.call(destination: "ana@example.com", locale: "en", ip: "1.1.1.1")

    expect(first.reload).not_to be_live
    expect(SignInCode.live.where(destination: "ana@example.com").count).to eq(1)
  end

  it "answers the same way for a known and an unknown address" do
    create(:user, :with_email, email_address: "known@example.com")

    known = described_class.call(destination: "known@example.com", locale: "en", ip: "1.1.1.1")
    unknown = described_class.call(destination: "nobody@example.com", locale: "en", ip: "1.1.1.1")

    expect(known).to be_success.and be_a(Result::Success)
    expect(unknown).to be_success
    expect(ActionMailer::Base.deliveries.size).to eq(2)
  end

  it "refuses a malformed or oversized address without touching the database" do
    expect(described_class.call(destination: "not-an-email", locale: "en", ip: "1.1.1.1").error).to include(code: :invalid_email)
    expect(described_class.call(destination: "#{"a" * 100}@example.com", locale: "en", ip: "1.1.1.1").error).to include(code: :invalid_email)
    expect(SignInCode.count).to eq(0)
  end

  it "is unavailable while mail is paused, and when the mail cannot be sent" do
    create(:platform_switch, service: "mail", paused: true)
    expect(described_class.call(destination: "ana@example.com", locale: "en", ip: "1.1.1.1").error).to include(code: :unavailable)
    expect(SignInCode.count).to eq(0)
    PlatformSwitch.delete_all
    Platform::Switchboard.bust!

    failing = instance_double(ActionMailer::MessageDelivery)
    allow(failing).to receive(:deliver_now).and_raise(Net::SMTPFatalError.new("550 ana@example.com rejected"))
    allow(SignInMailer).to receive(:code).and_return(failing)

    result = described_class.call(destination: "ana@example.com", locale: "en", ip: "1.1.1.1")
    expect(result.error).to include(code: :unavailable)
    expect(SignInCode.count).to eq(0)
  end
end
