require "rails_helper"

RSpec.describe "Native-only surfaces", type: :request do
  it "sends a browser to the informational site with a notice" do
    get sign_in_path(locale: "en")

    expect(response).to redirect_to(root_path(locale: "en"))
    follow_redirect!
    expect(response.body).to include(I18n.t("native_only.notice"))
  end

  it "serves the native shells" do
    get sign_in_path(locale: "en"), headers: native_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("sessions.new.title"))
  end

  it "opens to browsers when NATIVE_WEB_ACCESS is on" do
    with_native_web_access(true) do
      get sign_in_path(locale: "es")
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("sessions.new.title", locale: :es))
  end

  it "answers 403 to a JSON ceremony request from a browser" do
    post sign_in_options_path(locale: "en"), as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "gates the authenticated area too" do
    sign_in_as(create(:user))

    get app_root_path(locale: "en")
    expect(response).to redirect_to(root_path(locale: "en"))

    get app_root_path(locale: "en"), headers: native_headers
    expect(response).to have_http_status(:ok)
  end
end
