require "rails_helper"

# Social sign-in through OmniAuth's test mode (config/initializers/omniauth.rb registers
# every provider under test): the request phase redirects straight to the callback.
RSpec.describe "Sign in with Google, Apple or Microsoft", type: :request do
  def mock(provider, uid: "uid-1", email: "ana@example.com", verified: true, name: "Ana Ruiz")
    OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
      provider: provider, uid: uid, info: { email: email, email_verified: verified, name: name }
    )
  end

  def through(provider, params = {})
    post "/auth/#{provider}", params: params
    # Apple's registered return is /auth/apple/return, a POST from Apple that re-posts to the callback.
    return post("/auth/apple/callback") if response.location.to_s.end_with?("/auth/apple/return")

    expect(response).to redirect_to(%r{/auth/#{provider}/callback})
    follow_redirect!
  end

  after { OmniAuth.config.mock_auth.clear }

  it "offers every configured provider on sign-in and sign-up, in a browser only" do
    get "/en/sign_in"
    expect(response.body).to include('action="/auth/google_oauth2"').and include('action="/auth/apple"').and include('action="/auth/microsoft_graph"')
    expect(response.body).to include(I18n.t("sign_in_codes.social.continue", provider: "Google"))

    get "/en/sign_up"
    expect(response.body).to include('action="/auth/apple"')

    get "/en/sign_in", headers: native_headers
    expect(response.body).not_to include('action="/auth/google_oauth2"')
  end

  it "creates the account with the finder's field and signs in" do
    mock("google_oauth2", uid: "g-123")

    expect do
      through("google_oauth2", latitude: "42.0", longitude: "-93.75", location_source: "map", crop_name: "Corn", locale: "es")
    end.to change(User, :count).by(1).and change(Identity, :count).by(1).and change(Field, :count).by(1)

    user = User.last
    expect(user).to have_attributes(display_name: "Ana Ruiz", email_address: "ana@example.com", locale: "es")
    expect(user.email_verified_at).to be_present
    expect(user.sessions.last.sign_in_method).to eq("google_oauth2")
    expect(response).to redirect_to(%r{/app})
  end

  it "signs a returning person in with the linked account, without a new one" do
    user = create(:user)
    user.identities.create!(provider: "apple", uid: "a-1", email: "x@privaterelay.appleid.com", email_verified: true)
    mock("apple", uid: "a-1", email: "x@privaterelay.appleid.com")

    expect { through("apple") }.not_to change(User, :count)
    expect(user.sessions.last&.sign_in_method).to eq("apple")
  end

  it "never links an unverified address to an existing account" do
    create(:user, email_address: "ana@example.com")
    mock("microsoft_graph", uid: "m-1", verified: false)

    expect { through("microsoft_graph") }.not_to change(Identity, :count)
    expect(response).to redirect_to(%r{/sign_in})
    expect(flash[:alert]).to eq(I18n.t("omniauth_callbacks.errors.email_conflict", provider: "Microsoft"))
  end

  it "connects a provider from the account page, and disconnects it while another way in remains" do
    user = create(:user, email_address: "ana@example.com", email_verified_at: Time.current)
    sign_in_as(user, user_agent: "Mozilla/5.0")
    mock("google_oauth2", uid: "g-9")

    get "/en/passkeys"
    expect(response.body).to include(I18n.t("passkeys.index.connected.title")).and include(I18n.t("passkeys.index.connected.connect"))

    expect { through("google_oauth2", intent: "connect") }.to change { user.identities.count }.by(1)
    expect(response).to redirect_to(%r{/passkeys})

    delete "/en/identities/#{user.identities.first.id}"
    expect(user.identities.count).to eq(0)
  end

  it "keeps the last way in" do
    user = create(:user, email_address: nil, email_verified_at: nil)
    identity = user.identities.create!(provider: "google_oauth2", uid: "g-only")
    sign_in_as(user, user_agent: "Mozilla/5.0")

    delete "/en/identities/#{identity.id}"
    expect(flash[:alert]).to eq(I18n.t("identities.destroy.last_way_in"))
    expect(user.identities.count).to eq(1)
  end

  it "lands on the sign-in page with a message when the provider fails or the operator paused it" do
    get "/auth/failure", params: { message: "invalid_credentials" }
    expect(response).to redirect_to(%r{/sign_in})

    PlatformSwitch.create!(service: "oauth", paused: true)
    Rails.cache.clear
    post "/auth/google_oauth2"
    expect(response).to redirect_to("/auth/failure?message=paused")
  end

  it "re-posts Apple's cross-site answer from our own origin" do
    post "/auth/apple/return", params: { code: "c0de", state: "st4te", user: '{"name":{"firstName":"Ana"}}' }

    expect(response.body).to include('action="/auth/apple/callback"').and include('value="c0de"').and include('value="st4te"')
    expect(response.body).to match(/<script nonce="[^"]+">document.getElementById/)
  end

  it "shows the providers without credentials as disabled placeholders" do
    allow(Platform::Features).to receive(:oauth_providers).and_return(%w[google_oauth2])

    get "/en/sign_in"
    expect(response.body).to include('action="/auth/google_oauth2"')
    expect(response.body).not_to include('action="/auth/apple"')
    expect(response.body).to include(I18n.t("sign_in_codes.social.continue", provider: "Apple")).and include("auth-social__button--soon")
    expect(response.body.scan(I18n.t("sign_in_codes.social.soon")).size).to eq(2)
  end
end
