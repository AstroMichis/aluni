require "rails_helper"

# The Ask Aluni chat page and its Turbo Stream turns. The conversation engine
# (Onboarding::ReplyService and friends) is stubbed at the service boundary;
# undo runs for real against the row, and the last example runs one turn
# through the real engine with Gemini stubbed.
RSpec.describe "Ask Aluni chat", type: :request do
  let(:user) { create(:user, display_name: "Ana") }
  let(:stream_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }
  let(:total) { Onboarding::Topics.size }

  before { sign_in_as(user) }

  def payload(**overrides)
    {
      user_text: "Twelve and a half hectares on drip, soy before the corn",
      assistant_text: "Twelve and a half hectares, lovely. What grew there the year before?",
      transition: nil, topic: "crops", topic_complete: false,
      proposal: nil,
      applied: {
        "profile.goals" => %w[rotation],
        "field.area" => 12.5, "field.area_unit" => "hectares", "field.irrigation" => "drip",
        "field.soil.texture" => "medium",
        "crops.2024.main" => { "season_year" => 2024, "role" => "main", "crop_name" => "Soy", "scientific_name" => "Glycine max",
                               "planting_month" => 5, "harvest_month" => 10 }
      },
      progress: { index: 2, total: 5 }, completed: false, degraded: false, refusal: false
    }.merge(overrides)
  end

  describe "GET /app/onboarding" do
    it "renders the welcome bubble, the progress, the toast slot and the profile preview, creating the rows" do
      get app_onboarding_path(locale: "en")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("app.onboarding.show.title")).and include(I18n.t("app.onboarding.show.lede"))
      expect(response.body).to include(I18n.t("onboarding.welcome_message", name: "Ana"))
      expect(response.body).to include('id="onboarding-messages"').and include('data-controller="chat"')
      expect(response.body).to include('id="onboarding-toasts"').and include('aria-live="polite"')
      expect(response.body).to include(I18n.t("app.onboarding.show.progress.step", index: 1, total: total))
      expect(response.body).to include(I18n.t("app.onboarding.show.preview.title")).and include('id="profile-preview"')
      expect(response.body).to include('id="chat-companion"').and include("data-mascot-dock").and include('data-mascot-mode-value="docked"')
      expect(response.body).to include(I18n.t("app.onboarding.show.composer_placeholder")).and include(I18n.t("app.onboarding.show.skip"))
      expect(user.reload.onboarding_session).to be_present
      expect(user.farms.count).to eq(1)
    end

    it "has no location tools and no confirm card: setup settles the pin and facts are saved as they are said" do
      get app_onboarding_path(locale: "en")

      expect(response.body).not_to include("onboarding-location-tools")
      expect(response.body).not_to include("data-geolocate-")
      expect(response.body).not_to include("geolocate#locate")
      expect(response.body).not_to include("onboarding-confirm")
      expect(response.body).not_to include("accepted_fields")
    end

    it "resumes the transcript and the topic from the row" do
      create(:onboarding_session, user: user, topic: "crops",
             transcript: [ { "role" => "user", "text" => "Hola, soy Ana" }, { "role" => "assistant", "text" => "Hola Ana, tell me about your crops" } ])

      get app_onboarding_path(locale: "en")

      expect(response.body).to include("Hola, soy Ana").and include("Hola Ana, tell me about your crops")
      expect(response.body).not_to include(I18n.t("onboarding.welcome_message", name: "Ana"))
      expect(response.body).to include(I18n.t("app.onboarding.show.progress.step", index: 2, total: total))
    end

    it "speaks Spanish under /es" do
      get app_onboarding_path(locale: "es")

      expect(response.body).to include('lang="es"').and include(I18n.t("app.onboarding.show.title", locale: :es))
      expect(response.body).to include(I18n.t("onboarding.welcome_message", name: "Ana", locale: :es))
    end
  end

  describe "POST /app/onboarding/message" do
    it "answers a turn with both bubbles, a Saved toast with Undo, the refreshed preview and the progress" do
      farm = create(:farm, user: user, name: "Finca Ana")
      create(:field, farm: farm, area: 12.5, irrigation: :drip)
      allow(Onboarding::ReplyService).to receive(:call).and_return(Success(payload))

      post message_app_onboarding_path(locale: "en"), params: { text: "Twelve and a half hectares on drip, soy before the corn" }, headers: stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(Onboarding::ReplyService).to have_received(:call)
        .with(user: user, text: "Twelve and a half hectares on drip, soy before the corn", locale: :en, coords: nil)

      body = response.body
      expect(body).to include('target="onboarding-messages"').and include("soy before the corn").and include("Twelve and a half hectares, lovely.")
      expect(body).to include('target="onboarding-toasts"').and include('class="toast toast--success toast--with-action"').and include('data-toast-target="action"')
      expect(body).to include(%(action="#{undo_app_onboarding_path(locale: 'en')}")).and include('class="toast__action"').and include(I18n.t("app.onboarding.show.undo"))
      prefix = I18n.t("app.onboarding.show.applied", items: "").delete_suffix(".")
      summary = body[/#{Regexp.escape(prefix)}[^<]*/]
      expect(summary).to be_present
      expect(summary).to include("#{I18n.t('onboarding.field_labels.field.area')} 12.5 #{I18n.t('onboarding.values.area_unit.hectares')}")
      expect(summary).to include("#{I18n.t('onboarding.field_labels.field.irrigation')} #{I18n.t('onboarding.values.irrigation.drip')}")
      expect(summary).to include("#{I18n.t('onboarding.field_labels.field.soil.texture')} #{I18n.t('onboarding.values.texture.medium')}")
      expect(summary).to include("#{I18n.t('onboarding.field_labels.profile.goals')} #{I18n.t('onboarding.values.goals.rotation')}")
      expect(summary).to include("Soy (Glycine max)").and include("2024")
      expect(summary).not_to include("Area unit")
      expect(body).to include('target="profile-preview"').and include("Finca Ana").and include("12.5 hectares").and include(I18n.t("onboarding.values.irrigation.drip"))
      expect(body).to include('target="onboarding-progress"').and include(I18n.t("app.onboarding.show.progress.step", index: 2, total: total))
      expect(body).not_to include("onboarding-confirm")
      expect(body).not_to include("onboarding-location-tools")
    end

    it "summarises an applied pin as one Location item and passes posted coordinates to the engine" do
      allow(Onboarding::ReplyService).to receive(:call).and_return(Success(payload(applied: {
        "field.latitude" => 42.0, "field.longitude" => -93.75, "field.place_label" => "Near Ames",
        "field.location_confidence" => "confirmed", "field.location_source" => "geolocation"
      })))

      post message_app_onboarding_path(locale: "en"), params: { text: "Here", latitude: "42.0", longitude: "-93.75" }, headers: stream_headers

      expect(Onboarding::ReplyService).to have_received(:call).with(user: user, text: "Here", locale: :en, coords: { latitude: 42.0, longitude: -93.75 })
      expect(response.body).to include("#{I18n.t('onboarding.field_labels.field.location')} 42.0000, -93.7500 (Near Ames)")
      expect(response.body).not_to include(I18n.t("onboarding.field_labels.field.longitude"))
      expect(response.body).not_to include(I18n.t("onboarding.field_labels.field.location_source"))
    end

    it "shows no toast and leaves the preview alone when nothing was applied" do
      allow(Onboarding::ReplyService).to receive(:call).and_return(Success(payload(applied: nil)))

      post message_app_onboarding_path(locale: "en"), params: { text: "What is loam?" }, headers: stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('target="onboarding-toasts"')
      expect(response.body).not_to include('target="profile-preview"')
      expect(response.body).to include('target="onboarding-messages"').and include('target="onboarding-progress"')
    end

    it "appends the transition under a divider and the completion card when the chat is done" do
      allow(Onboarding::ReplyService).to receive(:call)
        .and_return(Success(payload(topic: "summary", transition: "Here is what I have so far.", applied: nil, completed: true, progress: { index: 5, total: 5 })))

      post message_app_onboarding_path(locale: "en"), params: { text: "Done" }, headers: stream_headers

      expect(response.body).to include("Here is what I have so far.").and include(I18n.t(Onboarding::Topics.title_key("summary")))
      expect(response.body).to include(I18n.t("app.onboarding.show.progress.step", index: total, total: total))
      expect(response.body).to include(I18n.t("app.onboarding.show.completion.title")).and include(I18n.t("app.onboarding.show.completion.cta"))
    end

    it "renders degraded and refusal turns" do
      allow(Onboarding::ReplyService).to receive(:call).and_return(Success(payload(degraded: true, applied: nil)))
      post message_app_onboarding_path(locale: "en"), params: { text: "Hello?" }, headers: stream_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("chat__message--degraded").and include(I18n.t("app.onboarding.show.degraded_note"))

      allow(Onboarding::ReplyService).to receive(:call).and_return(Success(payload(refusal: true, assistant_text: "Let us keep it kind.", applied: nil)))
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

  describe "POST /app/onboarding/undo" do
    it "restores the last applied facts, clears the toast and refreshes the preview" do
      farm = create(:farm, user: user, name: "Finca Ana")
      field = create(:field, farm: farm, area: 12.5, irrigation: :drip, soil: { "texture" => "medium" })
      create(:onboarding_session, user: user, topic: "soil", last_applied: {
        "before" => { "field" => { "area" => "3.0", "irrigation" => "rainfed" }, "soil" => {} },
        "applied" => { "field.area" => 12.5, "field.irrigation" => "drip", "field.soil.texture" => "medium" },
        "at" => Time.current.iso8601
      })

      post undo_app_onboarding_path(locale: "en"), headers: stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(field.reload).to have_attributes(area: 3, irrigation: "rainfed", soil: {})
      expect(user.onboarding_session.reload.last_applied).to eq({})
      body = response.body
      expect(body).to include('target="onboarding-toasts"').and include('target="profile-preview"').and include('target="onboarding-notice"')
      expect(body).to include("3 hectares").and include(I18n.t("onboarding.values.irrigation.rainfed")).and include(I18n.t("app.onboarding.undo.done"))
      expect(body).not_to include("12.5 hectares")
    end

    it "says so when there is nothing to undo" do
      post undo_app_onboarding_path(locale: "en"), headers: stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('target="onboarding-notice"').and include(I18n.t("app.onboarding.undo.nothing"))
    end

    it "sends a plain HTML submit back to the page with the notice as a flash" do
      post undo_app_onboarding_path(locale: "en")

      expect(response).to redirect_to(app_onboarding_path(locale: "en"))
      expect(flash[:alert]).to eq(I18n.t("app.onboarding.undo.nothing"))
    end
  end

  it "skips a topic, showing the divider, the transition and the new progress" do
    allow(Onboarding::SkipTopicService).to receive(:call).and_return(Success(topic: "soil", transition: "Let us talk about your soil.", completed: false))

    post skip_app_onboarding_path(locale: "en"), headers: stream_headers

    expect(response).to have_http_status(:ok)
    expect(Onboarding::SkipTopicService).to have_received(:call).with(user: user, locale: :en)
    expect(response.body).to include("Let us talk about your soil.").and include(I18n.t(Onboarding::Topics.title_key("soil")))
    expect(response.body).to include(I18n.t("app.onboarding.show.progress.step", index: 3, total: total))
    expect(response.body).not_to include(I18n.t("app.onboarding.show.completion.cta"))
  end

  it "completes and goes home with a 303" do
    allow(Onboarding::CompleteService).to receive(:call).and_return(Success(segment: "small_commercial"))

    post complete_app_onboarding_path(locale: "en")

    expect(response).to redirect_to(app_root_path(locale: "en"))
    expect(response).to have_http_status(:see_other)
    expect(Onboarding::CompleteService).to have_received(:call).with(user: user)
  end

  it "completes and opens the rotation plan when the main field has a crop" do
    field = create_farm_for(user)
    allow(Onboarding::CompleteService).to receive(:call).and_return(Success(segment: "small_commercial"))

    post complete_app_onboarding_path(locale: "en")

    expect(response).to redirect_to(app_field_rotation_path(field, locale: "en"))
    expect(response).to have_http_status(:see_other)
  end

  it "resets and comes back to the chat with a 303" do
    allow(Onboarding::ResetService).to receive(:call).and_return(Success())

    delete reset_app_onboarding_path(locale: "en")

    expect(response).to redirect_to(app_onboarding_path(locale: "en"))
    expect(response).to have_http_status(:see_other)
    expect(Onboarding::ResetService).to have_received(:call).with(user: user)
  end

  it "runs one turn through the real engine with Gemini stubbed, saving the fact and offering Undo", :gemini_api do
    answer = { safe: true, language: "en", abuse_type: "none", response_text: "Noted, Ana. What grew there before the corn?",
               topic_complete: false, location_guess: nil, updates: { profile: { role: "owner" } } }
    stub_request(:post, %r{generativelanguage\.googleapis\.com/}).to_return(
      status: 200, headers: { "Content-Type" => "application/json" },
      body: { candidates: [ { content: { parts: [ { text: answer.to_json } ] } } ] }.to_json
    )

    post message_app_onboarding_path(locale: "en"), params: { text: "I am Ana and I own the farm" }, headers: stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("I am Ana and I own the farm").and include('target="onboarding-messages"').and include('target="onboarding-progress"')
    expect(response.body).to include('target="onboarding-toasts"').and include(I18n.t("app.onboarding.show.undo"))
    expect(response.body).to include("#{I18n.t('onboarding.field_labels.profile.role')} #{I18n.t('onboarding.values.role.owner')}")
    expect(user.reload.farmer_profile.role).to eq("owner")
    session = user.onboarding_session
    expect(session.transcript).not_to be_empty
    expect(session.proposal).to eq({})
    expect(session.last_applied).to include("applied" => { "profile.role" => "owner" }, "before" => { "profile" => { "role" => "unknown" } })
  end
end
