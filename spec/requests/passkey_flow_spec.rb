require "rails_helper"

RSpec.describe "Passkey sign-up and sign-in", type: :request do
  let(:client) { fake_authenticator }

  def register!(display_name: "Ada", email_address: "ada@example.com", locale: "en")
    post sign_up_options_path(locale: locale), params: { display_name: display_name, email_address: email_address }, headers: native_headers, as: :json
    options = response.parsed_body
    credential = client.create(challenge: options["challenge"], user_verified: true)
    post sign_up_path(locale: locale), params: { credential: credential, nickname: "iPhone" }, headers: native_headers, as: :json
    credential
  end

  it "registers with a passkey, uses the app, signs out and signs back in" do
    get sign_up_path(locale: "en"), headers: native_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="passkey"').and include(I18n.t("registrations.new.title"))

    post sign_up_options_path(locale: "en"), params: { display_name: "Ada", email_address: "ada@example.com" }, headers: native_headers, as: :json
    expect(response).to have_http_status(:ok)
    options = response.parsed_body
    expect(options.dig("rp", "id")).to eq("www.example.com")
    expect(options.dig("authenticatorSelection", "residentKey")).to eq("required")
    expect(options.dig("authenticatorSelection", "userVerification")).to eq("required")
    expect(options.dig("user", "id")).to be_present

    credential = client.create(challenge: options["challenge"], user_verified: true)
    post sign_up_path(locale: "en"), params: { credential: credential, nickname: "iPhone" }, headers: native_headers, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body["redirect_to"]).to eq(app_root_url(locale: "en"))
    expect(response.cookies["locale"]).to eq("en")

    user = User.last
    expect(user).to have_attributes(display_name: "Ada", email_address: "ada@example.com", locale: "en")
    expect(user.passkeys.count).to eq(1)
    expect(user.passkeys.first).to have_attributes(external_id: credential["id"], nickname: "iPhone", transports: [ "internal" ])
    expect(cookies["session_id"]).to be_present

    # The home shows its recap at once, empty or not: nothing forces a chat.
    get app_root_path(locale: "en"), headers: native_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("app.home.show.eyebrow")).and include(I18n.t("app.home.show.greeting", name: "Ada"))

    get passkeys_path(locale: "en"), headers: native_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("iPhone").and include(I18n.t("passkeys.index.title"))

    delete sign_out_path(locale: "en"), headers: native_headers
    expect(response).to redirect_to(root_path(locale: "en"))
    expect(response).to have_http_status(:see_other)
    expect(Session.count).to eq(0)

    get app_root_path(locale: "en"), headers: native_headers
    expect(response).to redirect_to(sign_in_path(locale: "en"))

    get sign_in_path(locale: "en"), headers: native_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("sessions.new.button"))

    post sign_in_options_path(locale: "en"), headers: native_headers, as: :json
    expect(response).to have_http_status(:ok)
    request_options = response.parsed_body
    expect(request_options["allowCredentials"]).to eq([])
    expect(request_options["userVerification"]).to eq("required")

    assertion = client.get(challenge: request_options["challenge"], user_verified: true,
                           user_handle: WebAuthn.standard_encoder.decode(user.webauthn_id))
    post sign_in_path(locale: "en"), params: { credential: assertion }, headers: native_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["redirect_to"]).to eq(app_root_url(locale: "en"))
    expect(user.passkeys.first.reload.sign_count).to eq(1)
    expect(user.passkeys.first.last_used_at).to be_present

    get app_root_path(locale: "en"), headers: native_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("app.home.show.eyebrow"))
  end

  it "carries the field from the finder into the new account" do
    post sign_up_options_path(locale: "en"), headers: native_headers, as: :json, params: {
      display_name: "Ada", locale: "es",
      latitude: "42.00000", longitude: "-93.75000", place_label: "Ames, Iowa", country_code: "US", admin_area: "Iowa",
      location_source: "geolocation", crop_name: "maíz", irrigation: "irrigated", area: "12.5", area_unit: "acres"
    }
    expect(response).to have_http_status(:ok)

    credential = client.create(challenge: response.parsed_body["challenge"], user_verified: true)
    post sign_up_path(locale: "en"), params: { credential: credential }, headers: native_headers, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["redirect_to"]).to eq(app_root_url(locale: "es"))
    user = User.last
    expect(user).to have_attributes(display_name: "Ada", locale: "es")
    expect(user).to be_onboarding_complete
    farm = user.farms.sole
    expect(farm).to have_attributes(country_code: "US", admin_area: "Iowa")
    field = farm.fields.sole
    expect(field).to have_attributes(latitude: 42.0, longitude: -93.75, place_label: "Ames, Iowa", location_source: "geolocation",
                                     location_confidence: "confirmed", irrigation: "irrigated", area: 12.5, area_unit: "acres")
    expect(field.field_crops.sole).to have_attributes(crop_name: "Maíz", scientific_name: "Zea mays", season_year: Date.current.year, role: "main", source: "farmer")
    expect(user.farmer_profile.units).to eq("imperial")

    get app_field_path(field, locale: "es", tab: "data"), headers: native_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("42.0000, -93.7500")
  end

  it "creates the account even when the field cannot be saved, and ignores a pinless field" do
    allow(Fields::SaveSetupService).to receive(:call).and_return(Failure(code: :invalid, messages: [ "nope" ]))
    post sign_up_options_path(locale: "en"), params: { display_name: "Ada", latitude: "42", longitude: "-93.75" }, headers: native_headers, as: :json
    credential = client.create(challenge: response.parsed_body["challenge"], user_verified: true)
    post sign_up_path(locale: "en"), params: { credential: credential }, headers: native_headers, as: :json
    expect(response).to have_http_status(:created)
    expect(User.count).to eq(1)
    expect(Fields::SaveSetupService).to have_received(:call).once

    post sign_up_options_path(locale: "en"), params: { display_name: "Bea", crop_name: "maíz" }, headers: native_headers, as: :json
    credential = fake_authenticator.create(challenge: response.parsed_body["challenge"], user_verified: true)
    post sign_up_path(locale: "en"), params: { credential: credential }, headers: native_headers, as: :json
    expect(response).to have_http_status(:created)
    expect(Fields::SaveSetupService).to have_received(:call).once
    expect(User.last.farms).to be_empty
  end

  it "signs up in Spanish and keeps the locale on the account" do
    register!(locale: "es")

    expect(response).to have_http_status(:created)
    expect(User.last.locale).to eq("es")
    expect(response.parsed_body["redirect_to"]).to eq(app_root_url(locale: "es"))
  end

  it "keeps the language chosen in the finder, even from an English page" do
    post sign_up_options_path(locale: "en"), params: { display_name: "Ana", locale: "es" }, headers: native_headers, as: :json
    expect(response).to have_http_status(:ok)

    credential = client.create(challenge: response.parsed_body["challenge"], user_verified: true)
    post sign_up_path(locale: "en"), params: { credential: credential }, headers: native_headers, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["redirect_to"]).to eq(app_root_url(locale: "es"))
    expect(response.cookies["locale"]).to eq("es")
    expect(User.last.locale).to eq("es")
  end

  it "ignores a language it does not offer" do
    post sign_up_options_path(locale: "en"), params: { display_name: "Ana", locale: "fr" }, headers: native_headers, as: :json
    credential = client.create(challenge: response.parsed_body["challenge"], user_verified: true)
    post sign_up_path(locale: "en"), params: { credential: credential }, headers: native_headers, as: :json

    expect(response).to have_http_status(:created)
    expect(User.last.locale).to eq("en")
    expect(response.parsed_body["redirect_to"]).to eq(app_root_url(locale: "en"))
  end

  it "rejects a replayed assertion" do
    register!
    user = User.last
    post sign_in_options_path(locale: "en"), headers: native_headers, as: :json
    assertion = client.get(challenge: response.parsed_body["challenge"], user_verified: true,
                           user_handle: WebAuthn.standard_encoder.decode(user.webauthn_id))

    post sign_in_path(locale: "en"), params: { credential: assertion }, headers: native_headers, as: :json
    expect(response).to have_http_status(:ok)

    post sign_in_path(locale: "en"), params: { credential: assertion }, headers: native_headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to eq("verification_failed")
  end

  it "rejects a credential it never registered" do
    rogue = fake_authenticator
    rogue.create(challenge: WebAuthn.standard_encoder.encode(SecureRandom.random_bytes(32)), user_verified: true)
    post sign_in_options_path(locale: "en"), headers: native_headers, as: :json
    assertion = rogue.get(challenge: response.parsed_body["challenge"], user_verified: true)

    post sign_in_path(locale: "en"), params: { credential: assertion }, headers: native_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["error"]).to eq("unknown_credential")
  end

  it "answers 400 to a malformed credential and 422 to a stale registration" do
    post sign_in_path(locale: "en"), params: { credential: { id: "x" } }, headers: native_headers, as: :json
    expect(response).to have_http_status(:bad_request)

    post sign_up_path(locale: "en"), params: { credential: { id: "x", response: { clientDataJSON: "x" } } }, headers: native_headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to eq("registration_expired")
  end

  it "requires a display name" do
    post sign_up_options_path(locale: "en"), params: { display_name: "  " }, headers: native_headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to eq("display_name_required")
  end

  it "closes sign-up when SIGNUPS_ENABLED is off while sign-in stays open" do
    Rails.configuration.x.signups.enabled = false

    get sign_up_path(locale: "en"), headers: native_headers
    expect(response).to redirect_to(sign_in_path(locale: "en"))

    get sign_in_path(locale: "en"), headers: native_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(%(href="#{sign_up_path(locale: "en")}"))
  ensure
    Rails.configuration.x.signups.enabled = true
  end

  describe "managing passkeys" do
    before { register! }

    it "adds a second passkey and refuses to remove the last one" do
      user = User.last

      delete passkey_path(user.passkeys.first, locale: "en"), headers: native_headers
      expect(response).to redirect_to(passkeys_path(locale: "en"))
      expect(user.passkeys.count).to eq(1)

      post options_passkeys_path(locale: "en"), headers: native_headers, as: :json
      expect(response).to have_http_status(:ok)
      options = response.parsed_body
      expect(options["excludeCredentials"].map { |c| c["id"] }).to eq([ user.passkeys.first.external_id ])

      credential = fake_authenticator.create(challenge: options["challenge"], user_verified: true)
      post passkeys_path(locale: "en"), params: { credential: credential, nickname: "Tablet" }, headers: native_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(user.passkeys.count).to eq(2)

      delete passkey_path(user.passkeys.last, locale: "en"), headers: native_headers
      expect(response).to redirect_to(passkeys_path(locale: "en"))
      follow_redirect!(headers: native_headers)
      expect(response.body).to include(I18n.t("passkeys.destroy.removed"))
      expect(user.passkeys.count).to eq(1)
    end
  end
end
