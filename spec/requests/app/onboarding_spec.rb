require "rails_helper"

# The chat page and its Turbo Stream turns. The conversation engine
# (Onboarding::ReplyService and friends) is stubbed at the service boundary;
# the last example runs one turn through the real engine with Gemini stubbed.
RSpec.describe "Onboarding chat", type: :request do
  let(:user) { create(:user, display_name: "Ana") }
  let(:stream_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }
  let(:total) { Onboarding::Topics.size }

  before { sign_in_as(user) }

  def payload(**overrides)
    {
      user_text: "I farm 12 hectares near Ames",
      assistant_text: "Twelve hectares, lovely. Do you own the land?",
      transition: nil, topic: "land", topic_complete: false,
      proposal: {
        "profile" => { "budget_level" => "low", "goals" => %w[rotation] },
        "farm" => { "name" => "Finca Ana" },
        "field" => { "area" => 12.5, "area_unit" => "hectares", "latitude" => 42.0, "longitude" => -93.75, "place_label" => "Near Ames",
                     "location_confidence" => "approximate", "location_source" => "assistant", "soil" => { "texture" => "medium", "ph" => 6.1 } },
        "crops" => [ { "season_year" => 2025, "role" => "main", "crop_name" => "Corn", "scientific_name" => "Zea mays", "planting_month" => 4, "harvest_month" => 10 } ]
      },
      progress: { index: 3, total: 8 }, completed: false, degraded: false, refusal: false
    }.merge(overrides)
  end

  describe "GET /app/onboarding" do
    it "renders the welcome bubble, the progress and the profile preview, creating the rows" do
      get app_onboarding_path(locale: "en")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("onboarding.welcome_message", name: "Ana"))
      expect(response.body).to include('id="onboarding-messages"').and include('data-controller="chat geolocate"')
      expect(response.body).to include(I18n.t("app.onboarding.show.progress.step", index: 1, total: total))
      expect(response.body).to include(I18n.t("app.onboarding.show.preview.title")).and include('id="profile-preview"')
      expect(response.body).to include('id="chat-companion"').and include("data-mascot-dock").and include('data-mascot-mode-value="docked"')
      expect(response.body).to include(I18n.t("app.onboarding.show.composer_placeholder")).and include(I18n.t("app.onboarding.show.skip"))
      expect(user.reload.onboarding_session).to be_present
      expect(user.farms.count).to eq(1)
    end

    it "resumes the transcript, the topic and the staged proposal from the row" do
      create(:onboarding_session, user: user, topic: "land",
             transcript: [ { "role" => "user", "text" => "Hola, soy Ana" }, { "role" => "assistant", "text" => "Hola Ana, tell me about your farm" } ],
             proposal: { "farm" => { "name" => "Finca Ana" } })

      get app_onboarding_path(locale: "en")

      expect(response.body).to include("Hola, soy Ana").and include("Hola Ana, tell me about your farm")
      expect(response.body).not_to include(I18n.t("onboarding.welcome_message", name: "Ana"))
      expect(response.body).to include(I18n.t("app.onboarding.show.progress.step", index: 3, total: total))
      expect(response.body).to include(I18n.t("app.onboarding.show.confirm.save")).and include('value="farm.name"').and include("Finca Ana")
    end

    it "shows the location tools while the topic is location" do
      create(:onboarding_session, user: user, topic: "location")

      get app_onboarding_path(locale: "en")

      expect(response.body).to include('id="onboarding-location-tools"').and include(I18n.t("app.onboarding.show.share_location"))
    end

    it "speaks Spanish under /es" do
      get app_onboarding_path(locale: "es")

      expect(response.body).to include('lang="es"').and include(I18n.t("app.onboarding.show.title", locale: :es))
      expect(response.body).to include(I18n.t("onboarding.welcome_message", name: "Ana", locale: :es))
    end
  end

  describe "GET /app" do
    it "forwards to the onboarding until it is complete, then shows the menu dial" do
      get app_root_path(locale: "en")
      expect(response).to redirect_to(app_onboarding_path(locale: "en"))

      create(:onboarding_session, :completed, user: user)
      create(:farm, user: user, name: "Finca Ana")

      get app_root_path(locale: "en")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="radial-menu"').and include(I18n.t("app.home.show.greeting", name: user.display_name))
      expect(response.body).to include(I18n.t("app.home.show.talk_to", app_name: I18n.t("app_name"))).and include(%(href="#{app_onboarding_path(locale: 'en')}"))
      expect(response.body).to include(I18n.t("layouts.passkeys")).and include(I18n.t("layouts.sign_out"))
    end
  end

  describe "POST /app/onboarding/message" do
    it "answers a turn with both bubbles, the confirm card, the progress and the location tools" do
      allow(Onboarding::ReplyService).to receive(:call).and_return(Success(payload(topic: "location", progress: { index: 2, total: 8 })))

      post message_app_onboarding_path(locale: "en"), params: { text: "I farm 12 hectares near Ames", latitude: "42.0", longitude: "-93.75" }, headers: stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(Onboarding::ReplyService).to have_received(:call)
        .with(user: user, text: "I farm 12 hectares near Ames", locale: :en, coords: { latitude: 42.0, longitude: -93.75 })

      body = response.body
      expect(body).to include('target="onboarding-messages"').and include("I farm 12 hectares near Ames").and include("Twelve hectares, lovely.")
      expect(body).to include('value="farm.name"').and include("Finca Ana")
      expect(body).to include('value="field.soil.texture"').and include(I18n.t("onboarding.values.texture.medium"))
      expect(body).to include('value="field.soil.ph"').and include("6.1")
      expect(body).to include('value="profile.goals"').and include(I18n.t("onboarding.values.goals.rotation"))
      expect(body).to include('value="profile.budget_level"').and include(I18n.t("onboarding.values.budget_level.low"))
      expect(body).to include('value="crops.2025.main"').and include("Corn (Zea mays)")
      # The pin is one fact: a single Location row, never five.
      expect(body).to include('value="field.latitude"').and include(I18n.t("onboarding.field_labels.field.location")).and include("42.0000, -93.7500 (Near Ames)")
      expect(body).not_to include('value="field.longitude"')
      expect(body).not_to include('value="field.location_source"')
      expect(body).to include(I18n.t("app.onboarding.show.confirm.save")).and include(I18n.t("app.onboarding.show.confirm.not_now"))
      expect(body).to include('target="onboarding-progress"').and include(I18n.t("app.onboarding.show.progress.step", index: 2, total: total))
      expect(body).to include('target="onboarding-location-tools"').and include(I18n.t("app.onboarding.show.is_this_your_area")).and include("gibs.earthdata.nasa.gov")
    end

    it "appends the transition under a divider and the completion card when the chat is done" do
      allow(Onboarding::ReplyService).to receive(:call)
        .and_return(Success(payload(topic: "summary", transition: "Here is what I have so far.", proposal: nil, completed: true, progress: { index: 8, total: 8 })))

      post message_app_onboarding_path(locale: "en"), params: { text: "Done" }, headers: stream_headers

      expect(response.body).to include("Here is what I have so far.").and include(I18n.t(Onboarding::Topics.title_key("summary")))
      expect(response.body).to include(I18n.t("app.onboarding.show.progress.step", index: total, total: total))
      expect(response.body).to include(I18n.t("app.onboarding.show.completion.title")).and include(I18n.t("app.onboarding.show.completion.cta"))
      expect(response.body).not_to include(I18n.t("app.onboarding.show.confirm.save"))
    end

    it "renders degraded and refusal turns" do
      allow(Onboarding::ReplyService).to receive(:call).and_return(Success(payload(degraded: true, proposal: nil)))
      post message_app_onboarding_path(locale: "en"), params: { text: "Hello?" }, headers: stream_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("chat__message--degraded").and include(I18n.t("app.onboarding.show.degraded_note"))

      allow(Onboarding::ReplyService).to receive(:call).and_return(Success(payload(refusal: true, assistant_text: "Let us keep it kind.", proposal: nil)))
      post message_app_onboarding_path(locale: "en"), params: { text: "..." }, headers: stream_headers
      expect(response.body).to include("chat__message--refusal").and include("Let us keep it kind.")
    end

    it "answers a blocked person with a 429 notice stream" do
      allow(Onboarding::ReplyService).to receive(:call).and_return(Failure(code: :blocked, blocked_until: 1.day.from_now))

      post message_app_onboarding_path(locale: "en"), params: { text: "Hi" }, headers: stream_headers

      expect(response).to have_http_status(:too_many_requests)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('target="onboarding-notice"').and include(ERB::Util.html_escape(I18n.t("onboarding.blocked")))
      expect(response.body).to include(ERB::Util.html_escape(I18n.t("app.onboarding.show.blocked_title")))
    end

    it "answers 422 to an empty message" do
      allow(Onboarding::ReplyService).to receive(:call).and_return(Failure(code: :empty))

      post message_app_onboarding_path(locale: "en"), params: { text: "" }, headers: stream_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "sends a plain HTML submit back to the page" do
      allow(Onboarding::ReplyService).to receive(:call).and_return(Success(payload))

      post message_app_onboarding_path(locale: "en"), params: { text: "Hi" }

      expect(response).to redirect_to(app_onboarding_path(locale: "en"))
      expect(response).to have_http_status(:see_other)
    end
  end

  describe "POST /app/onboarding/confirm" do
    it "passes the accepted keys on, empties the card and refreshes the preview" do
      create(:onboarding_session, user: user, topic: "land", proposal: { "farm" => { "name" => "Finca Ana" }, "field" => { "area" => 12.5 } })
      farm = create(:farm, user: user, name: "Finca Ana")
      create(:field, farm: farm, area: 12.5)
      allow(Onboarding::ApplyProposalService).to receive(:call).and_return(Success(applied: { "farm.name" => "Finca Ana" }))

      post confirm_app_onboarding_path(locale: "en"), params: { accepted_fields: [ "farm.name", "field.area" ] }, headers: stream_headers

      expect(response).to have_http_status(:ok)
      expect(Onboarding::ApplyProposalService).to have_received(:call).with(user: user, accepted: [ "farm.name", "field.area" ])
      expect(response.body).to include('target="onboarding-confirm"').and include('target="profile-preview"').and include('target="onboarding-progress"')
      expect(response.body).to include("Finca Ana").and include("12.5 hectares").and include(I18n.t("app.onboarding.confirm.saved"))
    end

    it "tells the person when the proposal has expired" do
      allow(Onboarding::ApplyProposalService).to receive(:call).and_return(Failure(code: :expired))

      post confirm_app_onboarding_path(locale: "en"), params: { accepted_fields: [ "farm.name" ] }, headers: stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('target="onboarding-notice"').and include(I18n.t("app.onboarding.confirm.expired"))
    end
  end

  it "discards the staged proposal" do
    allow(Onboarding::DiscardProposalService).to receive(:call).and_return(Success())

    post discard_app_onboarding_path(locale: "en"), headers: stream_headers

    expect(response).to have_http_status(:ok)
    expect(Onboarding::DiscardProposalService).to have_received(:call).with(user: user)
    expect(response.body).to include('target="onboarding-confirm"').and include(I18n.t("app.onboarding.discard.done"))
  end

  it "skips a topic, showing the divider, the transition and the new progress" do
    allow(Onboarding::SkipTopicService).to receive(:call).and_return(Success(topic: "crops", transition: "Let us talk about your crops.", completed: false))

    post skip_app_onboarding_path(locale: "en"), headers: stream_headers

    expect(response).to have_http_status(:ok)
    expect(Onboarding::SkipTopicService).to have_received(:call).with(user: user, locale: :en)
    expect(response.body).to include("Let us talk about your crops.").and include(I18n.t(Onboarding::Topics.title_key("crops")))
    expect(response.body).to include(I18n.t("app.onboarding.show.progress.step", index: 4, total: total))
    expect(response.body).not_to include(I18n.t("app.onboarding.show.completion.cta"))
  end

  it "completes and goes home with a 303" do
    allow(Onboarding::CompleteService).to receive(:call).and_return(Success(segment: "small_commercial"))

    post complete_app_onboarding_path(locale: "en")

    expect(response).to redirect_to(app_root_path(locale: "en"))
    expect(response).to have_http_status(:see_other)
    expect(Onboarding::CompleteService).to have_received(:call).with(user: user)
  end

  it "resets and comes back to the chat with a 303" do
    allow(Onboarding::ResetService).to receive(:call).and_return(Success())

    delete reset_app_onboarding_path(locale: "en")

    expect(response).to redirect_to(app_onboarding_path(locale: "en"))
    expect(response).to have_http_status(:see_other)
    expect(Onboarding::ResetService).to have_received(:call).with(user: user)
  end

  it "runs one turn through the real engine with Gemini stubbed", :gemini_api do
    answer = { safe: true, language: "en", abuse_type: "none", response_text: "Welcome, Ana. Do you own the land you farm?",
               topic_complete: false, location_guess: nil, updates: { profile: { role: "owner" } } }
    stub_request(:post, %r{generativelanguage\.googleapis\.com/}).to_return(
      status: 200, headers: { "Content-Type" => "application/json" },
      body: { candidates: [ { content: { parts: [ { text: answer.to_json } ] } } ] }.to_json
    )

    post message_app_onboarding_path(locale: "en"), params: { text: "I am Ana and I own the farm" }, headers: stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("I am Ana and I own the farm").and include('target="onboarding-messages"').and include('target="onboarding-progress"')
    expect(user.reload.onboarding_session.transcript).not_to be_empty
  end
end
