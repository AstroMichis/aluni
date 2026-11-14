require "rails_helper"

RSpec.describe NotificationRouter do
  let(:registry) do
    { "purposes" => { "welcome" => { "audience" => "user", "category" => "transactional",
                                     "channels" => %w[push web_push email], "mailer" => "NotificationMailer#generic", "push_key" => "welcome" } } }
  end

  around { |example| Notifications::Purposes.with(registry) { example.run } }

  def deliver(user, key: "user:#{user.id}:welcome")
    described_class.deliver(recipient: user, purpose: :welcome, idempotency_key: key,
                            payload: { mailer_args: [ user, "Welcome", "Glad you are here." ] })
  end

  it "falls through unconfigured push channels to email and records every attempt" do
    user = create(:user, :with_email)

    delivery = nil
    expect { delivery = deliver(user) }.to have_enqueued_mail(NotificationMailer, :generic).with(user, "Welcome", "Glad you are here.")

    expect(delivery).to be_sent
    expect(delivery.channel).to eq("email")
    expect(delivery.attempts.map { |a| a["channel"] }).to eq(%w[push web_push email])
    expect(delivery.attempts.first).to include("result" => "skipped", "reason" => "push_not_configured")
  end

  it "sends the same message only once per idempotency key" do
    user = create(:user, :with_email)

    first = deliver(user)
    expect { expect(deliver(user)).to eq(first) }.not_to have_enqueued_mail

    expect(NotificationDelivery.count).to eq(1)
  end

  it "skips a person with no reachable channel and says why" do
    user = create(:user)

    delivery = deliver(user)

    expect(delivery).to be_skipped
    expect(delivery.failed_reason).to include("email: no_email")
  end

  it "requires an idempotency key and a known purpose" do
    user = create(:user)
    expect { described_class.deliver(recipient: user, purpose: :welcome, idempotency_key: "") }.to raise_error(ArgumentError)
    expect { described_class.deliver(recipient: user, purpose: :nope, idempotency_key: "x") }.to raise_error(Notifications::Purposes::UnknownPurpose)
  end
end
