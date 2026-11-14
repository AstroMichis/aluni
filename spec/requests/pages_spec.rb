require "rails_helper"

RSpec.describe "Informational site", type: :request do
  it "renders the landing page in English by default" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('lang="en"').and include(I18n.t("pages.home.headline"))
    expect(response.body).to include('data-controller="hero-scene"')
    expect(response.headers["Content-Security-Policy"]).to include("script-src 'self' 'nonce-")
  end

  it "renders the landing page in Spanish under /es" do
    get "/es"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('lang="es"').and include(I18n.t("pages.home.headline", locale: :es))
  end

  it "shows sign-in instead of the store links inside the native shells" do
    get "/en", headers: native_headers

    expect(response.body).to include(I18n.t("pages.home.sign_in")).and include("sign_in")
  end

  it "switches the locale and goes back where the person was" do
    get set_locale_path(new_locale: "es"), headers: { "HTTP_REFERER" => "http://www.example.com/en/sign_in?x=1" }

    expect(response).to redirect_to("/es/sign_in?x=1")
    expect(response.cookies["locale"]).to eq("es")

    get "/locale/fr"
    expect(response).to have_http_status(:not_found)
  end

  it "remembers the locale cookie on later visits" do
    get "/es"
    get "/"

    expect(response.body).to include('lang="es"')
  end

  it "serves the web app manifest and the service worker" do
    get "/manifest.json"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/manifest+json")
    expect(JSON.parse(response.body)["name"]).to eq("Aluni")

    get "/service-worker.js"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/javascript")
    expect(response.body).to include("notificationclick")
  end

  it "answers the health check" do
    get "/up"
    expect(response).to have_http_status(:ok)
  end
end
