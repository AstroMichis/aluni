require "rails_helper"

RSpec.describe "Device tokens", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  it "registers a token once and removes it" do
    post app_device_tokens_path(locale: "en"), params: { token: "abc", platform: "ios" }, headers: native_headers, as: :json
    expect(response).to have_http_status(:ok)

    post app_device_tokens_path(locale: "en"), params: { token: "abc", platform: "ios" }, headers: native_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(user.device_tokens.count).to eq(1)
    expect(user.device_tokens.first).to be_ios

    delete app_device_tokens_path(locale: "en"), params: { token: "abc" }, headers: native_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(user.device_tokens.count).to eq(0)
  end

  it "rejects an unknown platform" do
    post app_device_tokens_path(locale: "en"), params: { token: "abc", platform: "web" }, headers: native_headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "is closed to browsers while the web kill switch is off" do
    with_native_web_access(false) do
      post app_device_tokens_path(locale: "en"), params: { token: "abc", platform: "ios" }, as: :json
    end

    expect(response).to have_http_status(:forbidden)
  end
end
