require "rails_helper"

RSpec.describe "Web access kill switch", type: :request do
  it "opens sign-in to browsers by default" do
    get sign_in_path(locale: "en")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("sessions.new.title"))
  end

  it "opens the authenticated area to a signed-in browser" do
    sign_in_as(create(:user))

    get app_root_path(locale: "en")

    # Open: the home answers, instead of sending the browser back to the landing page.
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("app.home.show.recap_title"))
  end

  it "always serves the native shells" do
    with_native_web_access(false) do
      get sign_in_path(locale: "en"), headers: native_headers
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("sessions.new.title"))
  end

  it "sends a browser back to the landing page with a notice when NATIVE_WEB_ACCESS is off" do
    with_native_web_access(false) do
      get sign_in_path(locale: "es")
      expect(response).to redirect_to(root_path(locale: "es"))
      follow_redirect!
    end

    expect(response.body).to include(I18n.t("native_only.notice", locale: :es))
  end

  it "answers 403 to a JSON ceremony request from a browser when the switch is off" do
    with_native_web_access(false) do
      post sign_in_options_path(locale: "en"), as: :json
    end

    expect(response).to have_http_status(:forbidden)
  end

  it "gates the authenticated area too when the switch is off" do
    sign_in_as(create(:user))

    with_native_web_access(false) do
      get app_root_path(locale: "en")
      expect(response).to redirect_to(root_path(locale: "en"))

      get app_root_path(locale: "en"), headers: native_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("app.home.show.recap_title"))
    end
  end
end
