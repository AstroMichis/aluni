require "rails_helper"

# The scripted chat panel on the landing page (name, language, passkey). It is
# hidden markup until the mascot's "Let's go"; the Stimulus side is covered by
# spec/system/landing_chat_spec.rb.
RSpec.describe "Landing chat panel", type: :request do
  it "renders the scripted chat with both locale scripts for a browser" do
    get "/en"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="landing-chat"').and include('data-controller="landing-chat passkey"')
    expect(response.body).to include(%(data-passkey-options-url-value="/en/sign_up/options")).and include(%(data-passkey-submit-url-value="/en/sign_up"))
    expect(response.body).to include('id="landing-chat-companion"').and include("data-mascot-dock")
    expect(response.body).to include(I18n.t("landing_chat.script.ask_name", locale: :en)).and include(I18n.t("landing_chat.script.ask_name", locale: :es))
    expect(response.body).to include(I18n.t("landing_chat.script.english")).and include(I18n.t("landing_chat.script.spanish"))
    expect(response.body).to include('autocomplete="given-name"').and include(%(maxlength="#{User::NAME_MAX}"))
    expect(response.body).to include('name="display_name"').and include('name="locale"').and include('data-passkey-target="button"')
    expect(response.body).to include(I18n.t("landing_chat.have_account")).and include(%(href="/en/sign_in"))
  end

  it "renders the panel in Spanish under /es" do
    get "/es"

    expect(response.body).to include(I18n.t("landing_chat.title", app_name: I18n.t("app_name"), locale: :es))
    expect(response.body).to include(%(data-landing-chat-locale-value="es")).and include(%(data-passkey-options-url-value="/es/sign_up/options"))
  end

  it "welcomes a signed-in browser back instead of asking for a name" do
    sign_in_as(create(:user, display_name: "Ana"))

    get "/en"

    expect(response.body).to include(I18n.t("landing_chat.welcome_back", name: "Ana")).and include(%(href="/en/app"))
    expect(response.body).to include('id="landing-chat"')
    expect(response.body).not_to include('data-controller="landing-chat passkey"')
  end

  it "is absent inside the native shells" do
    get "/en", headers: native_headers

    expect(response.body).not_to include('id="landing-chat"')
  end

  it "is absent while sign-ups are closed" do
    Rails.configuration.x.signups.enabled = false

    get "/en"

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('id="landing-chat"')
  ensure
    Rails.configuration.x.signups.enabled = true
  end
end
