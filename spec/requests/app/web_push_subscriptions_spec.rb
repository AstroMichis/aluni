require "rails_helper"

RSpec.describe "Web push subscriptions", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  it "stores the browser subscription once per endpoint" do
    payload = { subscription: { endpoint: "https://push.example.com/abc", keys: { p256dh: "p", auth: "a" } } }

    post app_web_push_subscriptions_path(locale: "en"), params: payload, headers: native_headers, as: :json
    expect(response).to have_http_status(:created)

    post app_web_push_subscriptions_path(locale: "en"), params: payload, headers: native_headers, as: :json
    expect(response).to have_http_status(:created)
    expect(user.web_push_subscriptions.count).to eq(1)
  end

  it "rejects a non-https endpoint" do
    post app_web_push_subscriptions_path(locale: "en"), params: { subscription: { endpoint: "http://x", keys: { p256dh: "p", auth: "a" } } }, headers: native_headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end
end
