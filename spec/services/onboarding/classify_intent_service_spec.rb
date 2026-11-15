require "rails_helper"

RSpec.describe Onboarding::ClassifyIntentService do
  let(:client) { instance_double(Gemini::Client, last_error: nil) }

  def classify(text = "hello")
    described_class.call(text: text, client: client)
  end

  it "parses the verdict and asks Flash with the small schema" do
    allow(client).to receive(:generate).and_return({ safe: false, language: "es", abuse_type: "insult" }.to_json)

    result = classify("eres un inutil")

    expect(result).to be_success
    expect(result.value).to eq(safe: false, language: "es", abuse_type: "insult")
    expect(client).to have_received(:generate).with(
      "eres un inutil", hash_including(system_instruction: described_class::SYSTEM, response_schema: described_class::SCHEMA, max_tokens: 128)
    )
  end

  it "fails open when the client returns nil" do
    allow(client).to receive(:generate).and_return(nil)
    allow(client).to receive(:last_error).and_return(type: :rate_limited)

    expect(classify.value).to eq(safe: true, language: nil, abuse_type: "none")
  end

  it "fails open on malformed JSON" do
    allow(client).to receive(:generate).and_return("not json")

    expect(classify.value).to eq(safe: true, language: nil, abuse_type: "none")
  end

  it "fails open on a network error or a paused switch" do
    allow(client).to receive(:generate).and_raise(Faraday::TimeoutError)
    expect(classify.value[:safe]).to be(true)

    allow(client).to receive(:generate).and_raise(Platform::ServicePaused.new(:gemini))
    expect(classify.value[:safe]).to be(true)
  end

  it "keeps the verdict consistent" do
    allow(client).to receive(:generate).and_return({ safe: true, language: "fr", abuse_type: "insult" }.to_json)
    expect(classify.value).to eq(safe: true, language: nil, abuse_type: "none")

    allow(client).to receive(:generate).and_return({ safe: false, language: "en", abuse_type: "none" }.to_json)
    expect(classify.value).to eq(safe: false, language: "en", abuse_type: "off_topic_hostile")
  end
end
