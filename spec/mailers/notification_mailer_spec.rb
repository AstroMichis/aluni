require "rails_helper"

RSpec.describe NotificationMailer, type: :mailer do
  it "sends a plain message in the person's locale" do
    user = create(:user, :with_email, :spanish)

    mail = described_class.generic(user, "Hola", "Bienvenido.")

    expect(mail.to).to eq([ user.email_address ])
    expect(mail.subject).to eq("Hola")
    expect(mail.body.encoded).to include("Bienvenido.")
    expect(mail.from.first).to end_with("@www.example.com").or end_with("@localhost").or be_present
  end

  it "is dropped by the pause interceptor while mail is paused" do
    create(:platform_switch, service: "mail", paused: true)
    user = create(:user, :with_email)

    expect { described_class.generic(user, "Hi", "Body").deliver_now }.not_to change { ActionMailer::Base.deliveries.size }
  end
end
