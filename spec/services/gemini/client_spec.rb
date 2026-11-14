require "rails_helper"

RSpec.describe Gemini::Client do
  let(:endpoint) { %r{generativelanguage\.googleapis\.com/v1beta/models/gemini-3\.8-flash:generateContent} }
  let(:client) { described_class.new(model: :flash) }

  def gemini_response(text)
    { candidates: [ { content: { parts: [ { text: text } ] } } ] }.to_json
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:gemini, :api_key).and_return("test-key")
    allow(client).to receive(:sleep)
  end

  it "returns the generated text and sends the API key header" do
    stub = stub_request(:post, endpoint).with(headers: { "x-goog-api-key" => "test-key" })
                                        .to_return(status: 200, body: gemini_response("hello"), headers: { "Content-Type" => "application/json" })

    expect(client.generate("say hi")).to eq("hello")
    expect(client.last_error).to be_nil
    expect(stub).to have_been_requested
  end

  it "retries a 429 and succeeds" do
    stub_request(:post, endpoint).to_return(
      { status: 429, body: { error: { message: "Please retry in 1.2s" } }.to_json, headers: { "Content-Type" => "application/json" } },
      { status: 200, body: gemini_response("ok"), headers: { "Content-Type" => "application/json" } }
    )

    expect(client.generate("again")).to eq("ok")
    expect(client).to have_received(:sleep).once
  end

  it "returns nil and exposes last_error when retries are exhausted" do
    stub_request(:post, endpoint).to_return(status: 503, body: { error: { message: "busy" } }.to_json, headers: { "Content-Type" => "application/json" })

    expect(client.generate("tired")).to be_nil
    expect(client.last_error).to include(type: :service_unavailable, status: 503)
  end

  it "does not retry a plain API error" do
    stub = stub_request(:post, endpoint).to_return(status: 400, body: { error: { message: "bad request" } }.to_json, headers: { "Content-Type" => "application/json" })

    expect(client.generate("nope")).to be_nil
    expect(client.last_error[:type]).to eq(:api_error)
    expect(stub).to have_been_requested.once
  end

  it "repairs stripped unicode escapes in structured output" do
    stub_request(:post, endpoint).to_return(status: 200, body: gemini_response("{\"word\":\"importaci\n00f3n\"}"), headers: { "Content-Type" => "application/json" })

    text = client.generate("json please", response_schema: { type: "object" })

    expect(JSON.parse(text)).to eq("word" => "importación")
  end

  it "refuses to call Gemini while the service is paused" do
    create(:platform_switch, service: "gemini", paused: true)

    expect { client.generate("x") }.to raise_error(Platform::ServicePaused)
  end

  it "builds chat bodies in Gemini's contents format" do
    stub = stub_request(:post, endpoint).with { |req| JSON.parse(req.body).dig("contents", 0, "role") == "user" }
                                        .to_return(status: 200, body: gemini_response("reply"), headers: { "Content-Type" => "application/json" })

    expect(client.chat(messages: [ { role: "user", parts: [ { text: "hi" } ] } ])).to eq("reply")
    expect(stub).to have_been_requested
  end
end
