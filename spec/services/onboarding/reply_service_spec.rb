require "rails_helper"

# The orchestrator with its two sub-services stubbed: what gets stored and
# applied, what the payload looks like, and how every Gemini problem stays in
# character.
RSpec.describe Onboarding::ReplyService, type: :service do
  let(:user) { create(:user, display_name: "Ana") }
  let(:session) { user.onboarding_session || Onboarding::EnsureProfileService.call(user: user).value[:session] }
  let(:safe) { Success(safe: true, language: "en", abuse_type: "none") }
  let(:draft) do
    Success("response_text" => "Nice to meet you, Ana. Do you own the land or rent it?", "topic_complete" => false,
            "location_guess" => nil, "updates" => { "profile" => { "role" => "owner", "goals" => %w[rotation moon], "team" => "army" } })
  end

  before do
    allow(Onboarding::ClassifyIntentService).to receive(:call).and_return(safe)
    allow(Onboarding::DraftReplyService).to receive(:call).and_return(draft)
  end

  def reply(text = "I am the owner", locale: "en", coords: nil)
    described_class.call(user: user, text: text, locale: locale, coords: coords)
  end

  it "stores both turns, applies the filtered facts right away and answers with the payload shape" do
    result = reply

    expect(result).to be_success
    expect(result.value).to eq(
      user_text: "I am the owner",
      assistant_text: "Nice to meet you, Ana. Do you own the land or rent it?",
      transition: nil, topic: "welcome", topic_complete: false,
      proposal: nil,
      applied: { "profile.role" => "owner", "profile.goals" => [ "rotation" ] },
      progress: { index: 1, total: 5 }, completed: false, degraded: false, refusal: false
    )

    session.reload
    expect(session.transcript.map { |t| t.slice("role", "text") }).to eq([
      { "role" => "user", "text" => "I am the owner" },
      { "role" => "model", "text" => "Nice to meet you, Ana. Do you own the land or rent it?" }
    ])
    expect(session.transcript.last["at"]).to be_present
    expect(session.proposal).to eq({})
    expect(session).to have_attributes(turns_count: 1, language: "en", strikes: 0, fallbacks_count: 0)
    expect(session.last_message_at).to be_present
    expect(user.farmer_profile.reload).to have_attributes(role: "owner", goals: [ "rotation" ], team: "unknown")
  end

  it "remembers the last apply so the toast can undo it" do
    reply

    last = session.reload.last_applied
    expect(last["applied"]).to eq("profile.role" => "owner", "profile.goals" => [ "rotation" ])
    expect(last["before"]).to eq("profile" => { "role" => "unknown", "goals" => [] })
    expect(Time.iso8601(last["at"])).to be_within(1.minute).of(Time.current)
  end

  it "applies nothing and keeps last_applied untouched when the answer carries no facts" do
    session.update!(last_applied: { "before" => { "profile" => { "role" => "unknown" } }, "applied" => { "profile.role" => "owner" }, "at" => Time.current.iso8601 })
    allow(Onboarding::DraftReplyService).to receive(:call).and_return(Success(draft.value.merge("updates" => {})))

    result = reply("What is loam?")

    expect(result.value).to include(applied: nil, proposal: nil, degraded: false)
    expect(session.reload.last_applied["applied"]).to eq("profile.role" => "owner")
  end

  describe "when the apply fails" do
    it "logs, keeps the proposal staged and finishes the turn without a toast" do
      allow(Onboarding::ApplyProposalService).to receive(:call).and_return(Failure(code: :invalid, messages: [ "Position must be greater than or equal to 0" ]))
      allow(Rails.logger).to receive(:error).and_call_original

      result = reply

      expect(result).to be_success
      expect(result.value).to include(applied: nil, degraded: false, refusal: false,
                                      proposal: { "profile" => { "role" => "owner", "goals" => [ "rotation" ] } })
      expect(Onboarding::ApplyProposalService).to have_received(:call).with(user: user, accepted: %w[profile.role profile.goals])
      expect(Rails.logger).to have_received(:error).with(/keeping it staged/)
      session.reload
      expect(session.proposal).to eq("profile" => { "role" => "owner", "goals" => [ "rotation" ] })
      expect(session.last_applied).to eq({})
      expect(session.transcript.map { |t| t["role"] }).to eq(%w[user model])
      expect(user.farmer_profile.reload.role).to eq("unknown")
    end

    it "never halts the turn when the apply raises" do
      allow(Onboarding::ApplyProposalService).to receive(:call).and_raise(RuntimeError, "db hiccup")

      result = reply

      expect(result.value).to include(applied: nil, degraded: false, assistant_text: draft.value["response_text"])
      expect(session.reload.proposal).to eq("profile" => { "role" => "owner", "goals" => [ "rotation" ] })
    end
  end

  it "stores the redacted text and sends the classifier the redacted text too" do
    reply("call me at 555-123-4567 or ana@example.com")

    expect(session.reload.transcript.first["text"]).to eq("call me at [phone] or [email]")
    expect(Onboarding::ClassifyIntentService).to have_received(:call).with(text: "call me at [phone] or [email]")
  end

  it "builds the system prompt and proper multi-turn contents on the request thread" do
    session.update!(topic: "crops", turns_count: 2, transcript: [
      { "role" => "user", "text" => "hello", "at" => "2026-01-01T00:00:00Z" },
      { "role" => "model", "text" => "hi Ana", "at" => "2026-01-01T00:00:01Z" }
    ])

    reply("soy in 2024")

    expect(Onboarding::DraftReplyService).to have_received(:call) do |messages:, system_instruction:, client:|
      expect(messages).to eq([
        { role: "user", parts: [ { text: "hello" } ] },
        { role: "model", parts: [ { text: "hi Ana" } ] },
        { role: "user", parts: [ { text: "soy in 2024" } ] }
      ])
      expect(system_instruction).to include("CURRENT TOPIC: crops").and include("LANGUAGE LOCK").and include("FARMER: Ana").and include("KNOWN FIELD BASICS")
      expect(system_instruction).not_to include("OPENING LINE")
      expect(client).to be_a(Gemini::Client)
    end
  end

  it "tells the model about the welcome bubble on the very first turn" do
    reply

    expect(Onboarding::DraftReplyService).to have_received(:call) do |system_instruction:, **|
      expect(system_instruction).to include("OPENING LINE ALREADY SHOWN").and include(I18n.t("onboarding.welcome_message", name: "Ana", locale: :en))
    end
  end

  it "answers in Spanish copy when the locale is es" do
    allow(Onboarding::DraftReplyService).to receive(:call).and_return(Failure(code: :external_error, message: "boom"))

    result = reply("hola", locale: "es")

    expect(I18n.t("onboarding.continuations.welcome", locale: :es)).to include(result.value[:assistant_text])
    expect(session.reload.language).to eq("es")
  end

  describe "guards" do
    it "is Failure(:empty) for blank or tag-only text and stores nothing" do
      expect(reply("   ").error).to include(code: :empty)
      expect(reply("<br>").error).to include(code: :empty)
      expect(session.reload.transcript).to eq([])
    end

    it "is Failure(:blocked) while the session is blocked" do
      session.update!(blocked_until: 1.hour.from_now)

      result = reply
      expect(result.error).to include(code: :blocked)
      expect(result.error[:blocked_until]).to be_present
      expect(Onboarding::DraftReplyService).not_to have_received(:call)
    end
  end

  describe "an unsafe message" do
    before { allow(Onboarding::ClassifyIntentService).to receive(:call).and_return(Success(safe: false, language: "en", abuse_type: "insult")) }

    it "discards the draft, refuses in character, applies nothing and counts a strike" do
      result = reply("you are useless")

      expect(result.value).to include(assistant_text: I18n.t("onboarding.refusals.insult", locale: :en), refusal: true, degraded: false, proposal: nil, applied: nil)
      expect(session.reload.strikes).to eq(1)
      expect(session.proposal).to eq({})
      expect(session.last_applied).to eq({})
      expect(user.farmer_profile.reload.role).to eq("unknown")
      expect(session.transcript.last["text"]).to eq(I18n.t("onboarding.refusals.insult", locale: :en))
    end

    it "blocks after three strikes and refuses the next message outright" do
      session.update!(strikes: 2)

      result = reply("still useless")

      expect(result.value[:assistant_text]).to eq(I18n.t("onboarding.blocked", locale: :en))
      expect(session.reload.strikes).to eq(3)
      expect(session.blocked_until).to be_within(1.minute).of(24.hours.from_now)
      expect(reply("hello?").error).to include(code: :blocked)
    end

    it "falls back to the general refusal for an unknown abuse type" do
      allow(Onboarding::ClassifyIntentService).to receive(:call).and_return(Success(safe: false, language: "en", abuse_type: "weird"))

      expect(reply.value[:assistant_text]).to eq(I18n.t("onboarding.refusals.off_topic_hostile", locale: :en))
    end
  end

  describe "when the draft fails" do
    before { allow(Onboarding::DraftReplyService).to receive(:call).and_return(Failure(code: :external_error, message: "boom")) }

    it "answers with a continuation line, keeps the message pending and leaves the user turn in place" do
      result = reply("I farm 12 hectares")

      lines = I18n.t("onboarding.continuations.welcome", locale: :en)
      expect(result.value).to include(assistant_text: lines[0], degraded: true, refusal: false, topic: "welcome", applied: nil)
      session.reload
      expect(session.pending_message).to eq("I farm 12 hectares")
      expect(session.fallbacks_count).to eq(1)
      expect(session.transcript.map { |t| t["role"] }).to eq(%w[user model])
    end

    it "rotates the continuation lines" do
      session.update!(fallbacks_count: 1)
      lines = I18n.t("onboarding.continuations.welcome", locale: :en)

      expect(reply.value[:assistant_text]).to eq(lines[1 % lines.size])
    end

    it "replays the pending message into the next request and clears it" do
      reply("I farm 12 hectares")
      allow(Onboarding::DraftReplyService).to receive(:call).and_return(draft)

      result = reply("rainfed")

      expect(result.value[:degraded]).to be(false)
      expect(Onboarding::DraftReplyService).to have_received(:call).twice
      expect(Onboarding::DraftReplyService).to have_received(:call).with(hash_including(messages: array_including(
        { role: "user", parts: [ { text: "I farm 12 hectares\nrainfed" } ] }
      )))
      session.reload
      expect(session.pending_message).to be_nil
      expect(session.transcript.map { |t| t["text"] }).to include("I farm 12 hectares", "rainfed")
    end

    it "accumulates pending messages across two failures" do
      reply("first")
      reply("second")

      expect(session.reload.pending_message).to eq("first\nsecond")
      expect(session.fallbacks_count).to eq(2)
    end
  end

  it "answers with a continuation line when Gemini is paused" do
    allow(Onboarding::DraftReplyService).to receive(:call).and_return(Failure(code: :paused, message: "gemini is paused"))

    result = reply

    expect(result).to be_success
    expect(result.value[:degraded]).to be(true)
    expect(I18n.t("onboarding.continuations.welcome", locale: :en)).to include(result.value[:assistant_text])
  end

  it "never raises out: an unexpected error becomes a continuation line" do
    allow(Onboarding::DraftReplyService).to receive(:call).and_raise(RuntimeError, "unexpected")

    result = reply

    expect(result).to be_success
    expect(result.value).to include(degraded: true, topic: "welcome")
    expect(session.reload.pending_message).to eq("I am the owner")
  end

  describe "topic flow" do
    it "advances the topic and appends the transition when the topic is complete" do
      allow(Onboarding::DraftReplyService).to receive(:call).and_return(Success(draft.value.merge("topic_complete" => true)))

      result = reply

      transition = I18n.t("onboarding.transitions.crops", locale: :en)
      expect(result.value).to include(topic: "crops", topic_complete: true, transition: transition, progress: { index: 2, total: 5 }, completed: false)
      expect(session.reload.topic).to eq("crops")
      expect(session.transcript.last["text"]).to eq("#{draft.value['response_text']}\n#{transition}")
    end

    it "completes the onboarding and stores the segment on the last topic" do
      session.update!(topic: "summary")
      user.farmer_profile.update!(team: :family, budget_level: :low, market_channels: %w[own_use])
      user.farms.first.fields.first.update!(area: 1.2, area_unit: :hectares)
      allow(Onboarding::DraftReplyService).to receive(:call).and_return(Success("response_text" => "All set, Ana.", "topic_complete" => true, "updates" => {}))

      result = reply("yes, that is right")

      expect(result.value).to include(topic: "summary", completed: true, transition: nil, applied: nil, progress: { index: 5, total: 5 })
      expect(session.reload).to be_completed
      expect(user.farmer_profile.reload.segment).to eq("smallholder_subsistence")
      expect(session.transcript.last["text"]).to eq("All set, Ana.")
    end
  end

  describe "the pin" do
    let(:field) { user.farms.first.fields.first }

    it "writes browser coordinates as a confirmed geolocation pin" do
      result = reply("here I am", coords: { latitude: "9.934", longitude: -84.08 })

      expect(result.value[:applied]).to include(
        "field.latitude" => 9.934, "field.longitude" => -84.08, "field.location_confidence" => "confirmed", "field.location_source" => "geolocation"
      )
      expect(field.reload).to have_attributes(latitude: 9.934, longitude: -84.08, location_confidence: "confirmed", location_source: "geolocation")
    end

    it "writes a confident location guess as an approximate assistant pin" do
      guess = { "latitude" => 9.9, "longitude" => -84.1, "label" => "Cartago, Costa Rica", "confidence" => "medium" }
      allow(Onboarding::DraftReplyService).to receive(:call).and_return(Success(draft.value.merge("location_guess" => guess, "updates" => { "field" => { "area" => 3, "latitude" => 50 } })))

      result = reply("near Cartago")

      expect(result.value[:applied]).to eq(
        "field.area" => 3, "field.latitude" => 9.9, "field.longitude" => -84.1, "field.place_label" => "Cartago, Costa Rica",
        "field.location_confidence" => "approximate", "field.location_source" => "assistant"
      )
      expect(field.reload).to have_attributes(area: 3, latitude: 9.9, place_label: "Cartago, Costa Rica", location_source: "assistant")
    end

    it "ignores a low-confidence guess and out-of-range coordinates" do
      allow(Onboarding::DraftReplyService).to receive(:call).and_return(Success(draft.value.merge("location_guess" => { "latitude" => 9.9, "longitude" => -84.1, "confidence" => "low" })))

      applied = reply("somewhere", coords: { latitude: 120, longitude: 0 }).value[:applied]
      expect(applied.keys).to all(start_with("profile."))
      expect(field.reload.latitude).to be_nil
    end

    it "prefers the browser pin over a guess" do
      allow(Onboarding::DraftReplyService).to receive(:call).and_return(Success(draft.value.merge("location_guess" => { "latitude" => 1, "longitude" => 1, "confidence" => "high" })))

      applied = reply("here", coords: { latitude: 9.9, longitude: -84.1 }).value[:applied]
      expect(applied).to include("field.latitude" => 9.9, "field.location_source" => "geolocation")
    end
  end

  describe "the classifier thread" do
    around do |example|
      config = Rails.configuration.x.onboarding
      previous = config.gemini_timeout
      config.gemini_timeout = 0.05
      example.run
    ensure
      config.gemini_timeout = previous
    end

    it "counts an unfinished classifier as safe" do
      allow(Onboarding::ClassifyIntentService).to receive(:call) do
        sleep 0.3
        Success(safe: false, language: "en", abuse_type: "insult")
      end

      result = reply

      expect(result.value).to include(refusal: false, assistant_text: draft.value["response_text"])
      expect(session.reload.strikes).to eq(0)
    end

    it "counts a classifier that raised as safe" do
      allow(Onboarding::ClassifyIntentService).to receive(:call).and_raise(RuntimeError, "thread boom")

      expect(reply.value[:refusal]).to be(false)
    end
  end

  it "trims the transcript to max_turns" do
    turns = Array.new(40) { |i| { "role" => i.even? ? "user" : "model", "text" => "t#{i}", "at" => "2026-01-01T00:00:00Z" } }
    session.update!(transcript: turns, turns_count: 20)

    reply

    expect(session.reload.transcript.size).to eq(40)
    expect(session.transcript.first["text"]).to eq("t2")
    expect(session.transcript.last["text"]).to eq(draft.value["response_text"])
  end
end
