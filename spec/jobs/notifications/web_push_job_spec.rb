require "rails_helper"

RSpec.describe Notifications::WebPushJob do
  let(:user) { create(:user) }
  let(:subscription) { user.web_push_subscriptions.create!(endpoint: "https://push.example.com/abc", p256dh: "p", auth: "a") }

  before do
    allow(Notifications::WebPushConfig).to receive(:vapid).and_return(subject: "mailto:x@example.com", public_key: "pk", private_key: "sk")
  end

  it "sends the message to the browser and records the use" do
    allow(WebPush).to receive(:payload_send)

    described_class.perform_now(subscription.id, { title: "Hi" }.to_json)

    expect(WebPush).to have_received(:payload_send).with(hash_including(endpoint: subscription.endpoint, p256dh: "p", auth: "a"))
    expect(subscription.reload.last_used_at).to be_present
  end

  it "deletes a subscription the push service reports as expired" do
    gone = double("response", code: "410", body: "gone", inspect: "#<Net::HTTPGone 410>")
    allow(WebPush).to receive(:payload_send).and_raise(WebPush::ExpiredSubscription.new(gone, "push.example.com"))

    described_class.perform_now(subscription.id, "{}")

    expect(WebPushSubscription.where(id: subscription.id)).not_to exist
  end
end
