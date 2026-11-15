require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  around do |example|
    original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rack::Attack.cache.store = original_store
  end

  it "throttles passkey ceremonies per IP" do
    8.times do
      post sign_in_options_path(locale: "en"), headers: native_headers, as: :json
      expect(response).to have_http_status(:ok)
    end

    post sign_in_options_path(locale: "en"), headers: native_headers, as: :json

    expect(response).to have_http_status(:too_many_requests)
  end

  it "matches the auth paths with and without a locale prefix" do
    %w[/sign_in /es/sign_in/options /en/sign_up /passkeys/options /en/passkeys].each do |path|
      expect(path).to match(RACK_ATTACK_AUTH_PATH)
    end
    %w[/en /up /api/v1/me /en/sign_in/extra].each do |path|
      expect(path).not_to match(RACK_ATTACK_AUTH_PATH)
    end
  end

  it "throttles the assistant turns per IP" do
    # The middleware counts before the app answers, so the sign-in redirect is enough.
    20.times do
      post message_app_onboarding_path(locale: "en"), params: { text: "hi" }
      expect(response).to redirect_to(sign_in_path(locale: "en"))
    end

    post message_app_onboarding_path(locale: "en"), params: { text: "hi" }

    expect(response).to have_http_status(:too_many_requests)
  end

  it "matches the assistant paths with and without a locale prefix" do
    %w[/app/onboarding/message /en/app/onboarding/undo /es/app/onboarding/skip
       /en/app/onboarding/complete /es/app/onboarding/reset].each do |path|
      expect(path).to match(RACK_ATTACK_ASSISTANT_PATH)
    end
    %w[/en/app/onboarding /en/app /app/onboarding/message/extra /en/app/onboarding/show
       /en/app/onboarding/confirm /es/app/onboarding/discard].each do |path|
      expect(path).not_to match(RACK_ATTACK_ASSISTANT_PATH)
    end
  end

  it "throttles the place lookups per IP" do
    # A blank query never reaches the geocoder; the count is what matters here.
    20.times do
      get places_path(locale: "en")
      expect(response).to have_http_status(:ok)
    end

    get reverse_places_path(locale: "en", lat: "95", lon: "0")

    expect(response).to have_http_status(:too_many_requests)
  end

  it "matches the places paths with and without a locale prefix" do
    %w[/places /en/places /es/places/reverse /places/reverse].each do |path|
      expect(path).to match(RACK_ATTACK_PLACES_PATH)
    end
    %w[/en /en/places/extra /en/app /placesx].each do |path|
      expect(path).not_to match(RACK_ATTACK_PLACES_PATH)
    end
  end

  it "blocks vulnerability scanners" do
    get "/wp-login.php"

    expect(response).to have_http_status(:forbidden)
    expect(response.body).to eq("Forbidden")
  end
end
