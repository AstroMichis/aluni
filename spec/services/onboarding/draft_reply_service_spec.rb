require "rails_helper"

RSpec.describe Onboarding::DraftReplyService do
  let(:client) { instance_double(Gemini::Client, last_error: nil) }
  let(:messages) { [ { role: "user", parts: [ { text: "I own 12 hectares" } ] } ] }
  let(:answer) do
    { response_text: "Twelve hectares, lovely. Do you rent or own it?", topic_complete: false,
      location_guess: nil, updates: { field: { area: 12, area_unit: "hectares" } } }
  end

  def draft
    described_class.call(messages: messages, system_instruction: "SYSTEM", client: client)
  end

  it "returns the parsed answer and calls chat with the schema" do
    allow(client).to receive(:chat).and_return(answer.to_json)

    result = draft

    expect(result).to be_success
    expect(result.value).to include("response_text" => answer[:response_text], "topic_complete" => false)
    expect(result.value.dig("updates", "field", "area")).to eq(12)
    expect(client).to have_received(:chat).with(
      messages: messages, system_instruction: "SYSTEM", response_schema: described_class::RESPONSE_SCHEMA, max_tokens: 1024
    )
  end

  it "is an external_error when the client gives up" do
    allow(client).to receive(:chat).and_return(nil)
    allow(client).to receive(:last_error).and_return(type: :service_unavailable)

    expect(draft.error).to include(code: :external_error)
  end

  it "is an external_error on malformed or empty answers" do
    allow(client).to receive(:chat).and_return("{ nope")
    expect(draft.error[:code]).to eq(:external_error)

    allow(client).to receive(:chat).and_return({ topic_complete: true }.to_json)
    expect(draft.error[:code]).to eq(:external_error)
  end

  it "is an external_error on a network failure" do
    allow(client).to receive(:chat).and_raise(Faraday::ConnectionFailed.new("down"))

    expect(draft.error[:code]).to eq(:external_error)
  end

  it "turns a paused switch into Failure(:paused) instead of raising" do
    allow(client).to receive(:chat).and_raise(Platform::ServicePaused.new(:gemini))

    expect(draft.error).to include(code: :paused)
  end

  describe "RESPONSE_SCHEMA" do
    let(:schema) { described_class::RESPONSE_SCHEMA }
    let(:updates) { schema.dig(:properties, :updates, :properties) }

    it "takes every enum from the models" do
      expect(updates.dig(:profile, :properties, "role", :enum)).to eq(FarmerProfile.roles.keys - [ "unknown" ])
      expect(updates.dig(:profile, :properties, "goals", :items, :enum)).to eq(FarmerProfile::GOALS)
      expect(updates.dig(:profile, :properties, "practices", :items, :enum)).to eq(FarmerProfile::PRACTICES)
      expect(updates.dig(:field, :properties, :irrigation, :enum)).to eq(Field.irrigations.keys - [ "unknown" ])
      expect(updates.dig(:field, :properties, :soil_texture, :enum)).to eq(Field::SOIL["texture"])
      expect(updates.dig(:field, :properties, :soil_problems, :items, :enum)).to eq(Field::SOIL["problems"])
      expect(updates.dig(:crops, :items, :properties, :role, :enum)).to eq(FieldCrop.roles.keys)
      expect(schema.dig(:properties, :location_guess, :nullable)).to be(true)
    end

    it "stays inside the Gemini schema subset" do
      allowed = %i[type properties required enum items nullable]
      walk = lambda do |node|
        expect(node.keys.map(&:to_sym) - allowed).to be_empty
        node[:properties]&.each_value { |child| walk.call(child) }
        walk.call(node[:items]) if node[:items]
      end
      walk.call(schema)
      expect(schema[:required]).to eq(%w[response_text topic_complete])
    end
  end
end
