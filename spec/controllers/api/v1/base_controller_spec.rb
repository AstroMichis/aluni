require "rails_helper"

RSpec.describe Api::V1::BaseController, type: :controller do
  controller do
    def create
      render json: { ok: true, user_id: current_user.id }
    end
  end

  before do
    routes.draw { post "create" => "api/v1/base#create" }
  end

  it "refuses a write without the native header" do
    post :create

    expect(response).to have_http_status(:forbidden)
  end

  it "refuses a write without a session" do
    request.headers["X-Aluni-Native"] = "1"

    post :create

    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts a write with the header and a session cookie" do
    user = create(:user)
    session = user.sessions.create!(user_agent: "spec", ip_address: "127.0.0.1")
    request.headers["X-Aluni-Native"] = "1"
    request.cookie_jar.signed[:session_id] = session.id

    post :create

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("ok" => true, "user_id" => user.id)
  end
end
