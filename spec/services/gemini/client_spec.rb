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

  it "asks chat for structured JSON when a schema is given" do
    schema = { type: "object", properties: { reply: { type: "string" } }, required: [ "reply" ] }
    stub = stub_request(:post, endpoint).with do |req|
      config = JSON.parse(req.body).fetch("generationConfig")
      config["responseMimeType"] == "application/json" && config["responseSchema"] == JSON.parse(schema.to_json) && config["maxOutputTokens"] == 256
    end.to_return(status: 200, body: gemini_response("{\"reply\":\"importaci\n00f3n\"}"), headers: { "Content-Type" => "application/json" })

    text = client.chat(messages: [ { role: "user", parts: [ { text: "hi" } ] } ], response_schema: schema, max_tokens: 256)

    expect(JSON.parse(text)).to eq("reply" => "importación")
    expect(stub).to have_been_requested
  end

  it "leaves plain chat answers untouched and uses the configured token limit" do
    stub = stub_request(:post, endpoint).with do |req|
      config = JSON.parse(req.body).fetch("generationConfig")
      !config.key?("responseMimeType") && config["maxOutputTokens"] == Rails.configuration.x.gemini.chat_max_output_tokens
    end.to_return(status: 200, body: gemini_response("importaci\n00f3n"), headers: { "Content-Type" => "application/json" })

    expect(client.chat(messages: [ { role: "user", parts: [ { text: "hi" } ] } ])).to eq("importaci\n00f3n")
    expect(stub).to have_been_requested
  end

  it "takes a per-call read timeout" do
    quick = described_class.new(model: :flash, timeout: 7)

    expect(quick.send(:connection).options.timeout).to eq(7)
    expect(client.send(:connection).options.timeout).to eq(30)
  end

  context "with the Vertex AI backend" do
    let(:vertex_endpoint) do
      "https://aiplatform.googleapis.com/v1/projects/test-project/locations/global/publishers/google/models/gemini-3.8-flash:generateContent"
    end
    let(:metadata_url) { Gemini::VertexToken::METADATA_URL }

    around do |example|
      config = Rails.configuration.x.gemini
      saved = [ config.backend, config.vertex_project, config.vertex_location ]
      config.backend = "vertex"
      config.vertex_project = "test-project"
      config.vertex_location = "global"
      Gemini::VertexToken.reset!
      example.run
    ensure
      config.backend, config.vertex_project, config.vertex_location = saved
      Gemini::VertexToken.reset!
    end

    it "is configured by the project alone, without an API key" do
      allow(Rails.application.credentials).to receive(:dig).with(:gemini, :api_key).and_return(nil)

      expect(described_class.configured?).to be(true)
    end

    it "calls Vertex AI with a metadata-server token and no API key" do
      token = stub_request(:get, metadata_url).with(headers: { "Metadata-Flavor" => "Google" })
                                              .to_return(status: 200, body: { access_token: "ya29.test", expires_in: 3599 }.to_json)
      call = stub_request(:post, vertex_endpoint).with(headers: { "Authorization" => "Bearer ya29.test" }) { |req| !req.headers.key?("X-Goog-Api-Key") }
                                                 .to_return(status: 200, body: gemini_response("hola"), headers: { "Content-Type" => "application/json" })

      expect(client.generate("hi")).to eq("hola")
      expect(client.generate("again")).to eq("hola")
      expect(call).to have_been_requested.twice
      expect(token).to have_been_requested.once
    end

    it "uses the regional host for a regional location" do
      Rails.configuration.x.gemini.vertex_location = "us-central1"

      expect(described_class.base_url).to eq("https://us-central1-aiplatform.googleapis.com/v1/projects/test-project/locations/us-central1/publishers/google/")
    end

    it "returns nil with an api_error when no token can be fetched" do
      stub_request(:get, metadata_url).to_return(status: 404, body: "")

      expect(client.generate("hi")).to be_nil
      expect(client.last_error).to include(type: :api_error)
      expect(client.last_error[:message]).to include("Vertex AI token")
    end
  end
end
