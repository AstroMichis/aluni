require "rails_helper"

RSpec.describe SignInMailer, type: :mailer do
  let(:record) { create(:sign_in_code, destination: "ana@example.com", locale: "es") }

  it "sends the code and the link in the person's locale" do
    mail = described_class.code(sign_in_code: record, code: "123456", link: "tok")

    expect(mail.to).to eq([ "ana@example.com" ])
    expect(mail.subject).to eq(I18n.t("sign_in_mailer.code.subject", code: "123 456", app_name: "Aluni", locale: :es))
    expect(mail.text_part.decoded).to include("123 456").and include("/es/sign_in/link?token=tok")
    expect(mail.html_part.decoded).to include("123 456").and include(I18n.t("sign_in_mailer.code.ignore", locale: :es))
  end

  it "is dropped by the pause interceptor while mail is paused" do
    create(:platform_switch, service: "mail", paused: true)

    expect { described_class.code(sign_in_code: record, code: "123456", link: "tok").deliver_now }
      .not_to change { ActionMailer::Base.deliveries.size }
  end
end
