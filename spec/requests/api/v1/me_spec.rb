require "rails_helper"

RSpec.describe "GET /api/v1/me", type: :request do
  it "answers 401 without a session cookie" do
    get "/api/v1/me"

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq("error" => "unauthorized")
  end

  it "returns the signed-in account" do
    user = create(:user, :with_email, display_name: "Grace")
    create(:passkey, user: user)
    sign_in_as(user)

    get "/api/v1/me", headers: native_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("id" => user.id, "display_name" => "Grace", "locale" => "en", "passkeys_count" => 1)
  end
end
