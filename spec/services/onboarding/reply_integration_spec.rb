require "rails_helper"

# The whole turn against Gemini's HTTP surface (WebMock): the classifier and
# the draft are told apart by their response schemas because they run in
# parallel. Tagged :gemini_api because the suite otherwise fails on any request
# that reaches a Google host (spec/support/external_apis.rb).
RSpec.describe Onboarding::ReplyService, "against the Gemini HTTP API", :gemini_api do
  let(:endpoint) { %r{generativelanguage\.googleapis\.com/v1beta/models/[^:]+:generateContent} }
  let(:user) { create(:user, display_name: "Ana", locale: "es") }

  def gemini_response(payload)
    { candidates: [ { content: { parts: [ { text: payload.to_json } ] } } ] }.to_json
  end

  def schema_properties(request)
    JSON.parse(request.body).dig("generationConfig", "responseSchema", "properties") || {}
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:gemini, :api_key).and_return("test-key")
    allow_any_instance_of(Gemini::Client).to receive(:sleep)
  end

  it "classifies and drafts in one turn, sending the schema, the lock, the guidance, the snapshot and both roles" do
    create(:farm, user: user, name: "Finca Ana").then { |farm| create(:field, farm: farm) }
    Onboarding::EnsureProfileService.call(user: user).value[:session].update!(topic: "land", turns_count: 2, transcript: [
      { "role" => "user", "text" => "Hola", "at" => "2026-01-01T00:00:00Z" },
      { "role" => "model", "text" => "Hola Ana, ¿cómo trabajas la tierra?", "at" => "2026-01-01T00:00:01Z" }
    ])

    classifier = stub_request(:post, endpoint).with { |req| schema_properties(req).key?("safe") }
                                              .to_return(status: 200, body: gemini_response(safe: true, language: "es", abuse_type: "none"),
                                                         headers: { "Content-Type" => "application/json" })
    draft_bodies = []
    draft = stub_request(:post, endpoint).with { |req| schema_properties(req).key?("response_text") && draft_bodies.push(JSON.parse(req.body)) }
                                         .to_return(status: 200, body: gemini_response(
                                           response_text: "Doce hectáreas, qué bien. ¿Es tuya o la alquilas?", topic_complete: false,
                                           location_guess: nil, updates: { field: { area: 12, area_unit: "hectares", soil_texture: "medium" } }
                                         ), headers: { "Content-Type" => "application/json" })

    result = described_class.call(user: user, text: "Tengo 12 hectáreas", locale: "es")

    expect(result).to be_success
    expect(result.value).to include(
      assistant_text: "Doce hectáreas, qué bien. ¿Es tuya o la alquilas?",
      proposal: { "field" => { "area" => 12, "area_unit" => "hectares", "soil" => { "texture" => "medium" } } },
      degraded: false, refusal: false
    )
    expect(classifier).to have_been_requested.once
    expect(draft).to have_been_requested.once

    body = draft_bodies.uniq.sole
    system = body.dig("systemInstruction", "parts", 0, "text")
    config = body.fetch("generationConfig")
    expect(config["responseMimeType"]).to eq("application/json")
    expect(config["responseSchema"]).to eq(JSON.parse(Onboarding::DraftReplyService::RESPONSE_SCHEMA.to_json))
    expect(config["maxOutputTokens"]).to eq(1024)
    expect(system).to include("ALWAYS respond in Spanish").and include("CURRENT TOPIC: land")
    expect(system).to include(Onboarding::Topics.guidance("land").lines.first.strip)
    expect(system).to include("FARMER: Ana").and include("farm: Finca Ana").and include("12.5 hectares")
    expect(body.fetch("contents").map { |c| c["role"] }).to eq(%w[user model user])
    expect(body.dig("contents", 2, "parts", 0, "text")).to eq("Tengo 12 hectáreas")
  end

  it "stays in character when Gemini is down and when it is paused" do
    stub_request(:post, endpoint).to_return(status: 503, body: { error: { message: "busy" } }.to_json, headers: { "Content-Type" => "application/json" })

    result = described_class.call(user: user, text: "Hola", locale: "es")
    expect(result.value).to include(degraded: true, refusal: false)
    expect(I18n.t("onboarding.continuations.welcome", locale: :es)).to include(result.value[:assistant_text])

    create(:platform_switch, service: "gemini", paused: true)
    Platform::Switchboard.bust!

    paused = described_class.call(user: user, text: "¿Sigues ahí?", locale: "es")
    expect(paused).to be_success
    expect(paused.value[:degraded]).to be(true)
    expect(user.onboarding_session.reload.pending_message).to eq("Hola\n¿Sigues ahí?")
  end
end
