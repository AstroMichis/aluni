require "rails_helper"

RSpec.describe "Public site", type: :request do
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

  it "walks through the tour and ends with the store buttons" do
    get "/en"

    expect(response.body).to include('data-controller="scroll-story"').and include('id="tour-step-1"').and include('id="tour-step-5"')
    expect(response.body).to include(I18n.t("pages.home.steps.location.title")).and include(I18n.t("pages.home.steps.alerts.title"))
    expect(response.body).to include(I18n.t("pages.home.capabilities.title")).and include('id="get-the-app"')
    expect(response.body.scan("store-button__badge").size).to eq(2)
    expect(response.body).not_to include("apps.apple.com")
  end

  it "shows on the tour only what the app computes for the Ames pin" do
    get "/en"

    expect(response.body).to include("1702 growing degree days").and include("82/100").and include("68/100").and include("60/100")
    expect(response.body).to include(I18n.t("pages.home.steps.compare.other_family")).and include(I18n.t("pages.home.steps.alerts.scout"))
    expect(response.body).to include("38 days this summer").and include('href="/en/evidence"')
    %w[1915 six\ years Root\ zone\ drying].each { |claim| expect(response.body).not_to include(claim) }
    expect(response.body.scan("phone-frame__chip-year").size).to eq(5)
  end

  it "links the store badges once the urls are configured" do
    allow(NativeApp).to receive_messages(
      app_store_url: "https://apps.apple.com/app/id1",
      play_store_url: "https://play.google.com/store/apps/details?id=us.aluni.app"
    )

    get "/en"

    expect(response.body).to include('href="https://apps.apple.com/app/id1"').and include('rel="noopener"')
    expect(response.body).to include('href="https://play.google.com/store/apps/details?id=us.aluni.app"')
    expect(response.body).not_to include("store-button__badge")
  end

  it "offers the field finder and sign-in to browsers" do
    get "/en"

    expect(response.body).to include(I18n.t("pages.home.find_my_field")).and include(%(data-emit-event-value="mascot:lets-go"))
    expect(response.body).to include(I18n.t("pages.home.sign_in")).and include(%(href="/en/sign_in"))
    expect(response.body).to include(I18n.t("pages.home.finish")).and include(I18n.t("pages.home.preview_notice_link"))
    expect(response.body).not_to include(%(href="/en/sign_up"))
  end

  it "lets Aluni's first bubble settle language and comfort on a first visit" do
    get "/en"
    expect(response.body).to include('data-controller="intro"').and include(I18n.t("intro.language_switch")).and include(I18n.t("intro.comfort"))
    expect(response.body).to include(%(name="preferred_locale" type="submit" value="es"))

    get "/es"
    expect(response.body).to include(I18n.t("intro.language_switch", locale: :es))
  end

  it "skips the intro once it was answered and never shows it to the native shells" do
    cookies[Preferences::COOKIE.to_s] = { seen_welcome: true, text_size: "large" }.to_json
    get "/en"
    expect(response.body).not_to include('data-controller="intro"')
    expect(response.body).to include('data-text-size="large"').and include(I18n.t("mascot.find_my_field"))

    cookies.delete(Preferences::COOKIE.to_s)
    get "/en", headers: native_headers
    expect(response.body).not_to include('data-controller="intro"')
  end

  it "offers the app to a signed-in browser" do
    sign_in_as(create(:user))

    get "/en"

    expect(response.body).to include(I18n.t("pages.home.open_app", app_name: I18n.t("app_name"))).and include(%(href="/en/app"))
    expect(response.body).not_to include(%(href="/en/sign_up"))
  end

  it "shows sign-in instead of the tour and the store links inside the native shells" do
    get "/en", headers: native_headers

    expect(response.body).to include(I18n.t("pages.home.sign_in")).and include("sign_in")
    expect(response.body).not_to include('data-controller="scroll-story"')
    expect(response.body).not_to include("store-button__badge")
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
