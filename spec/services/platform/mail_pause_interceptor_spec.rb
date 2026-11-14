require "rails_helper"

RSpec.describe Platform::MailPauseInterceptor do
  let(:message) { Mail::Message.new(to: "someone@example.com", subject: "Hi", body: "Hello") }

  it "lets mail through when mail is not paused" do
    described_class.delivering_email(message)
    expect(message.perform_deliveries).to be(true)
  end

  it "drops mail while mail is paused" do
    create(:platform_switch, service: "mail", paused: true)

    described_class.delivering_email(message)

    expect(message.perform_deliveries).to be(false)
  end

  it "always lets critical mail through" do
    create(:platform_switch, service: "mail", paused: true)
    message[Platform::MailPauseInterceptor::CRITICAL_HEADER] = "1"

    described_class.delivering_email(message)

    expect(message.perform_deliveries).to be(true)
  end

  it "is registered with Action Mailer" do
    expect(Mail.class_variable_get(:@@delivery_interceptors)).to include(described_class)
  end
end
