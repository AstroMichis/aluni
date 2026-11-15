require "rails_helper"

RSpec.describe Crops::NormalizeService, type: :service do
  def gemini_answer(text)
    client = instance_double(Gemini::Client, generate: text)
    allow(Gemini::Client).to receive(:new).with(model: :flash, timeout: 10).and_return(client)
    client
  end

  it "answers from the catalog without instantiating Gemini" do
    expect(Gemini::Client).not_to receive(:new)

    result = described_class.call(text: " Maiz ", locale: :es)

    expect(result).to be_success
    expect(result.value).to eq(crop_name: "Maíz", scientific_name: "Zea mays", confidence: "high", key: "maize")
  end

  it "rejects an empty text" do
    expect(described_class.call(text: "  ", locale: :en).error[:code]).to eq(:empty)
  end

  context "when Gemini is configured" do
    before { allow(Platform::Features).to receive(:gemini?).and_return(true) }

    it "asks Gemini once for an unknown crop, with the language lock and the schema" do
      client = gemini_answer({ crop_name: "Lulo", scientific_name: "Solanum quitoense", confidence: "high" }.to_json)

      result = described_class.call(text: "lulo", locale: :es)

      expect(result.value).to eq(crop_name: "Lulo", scientific_name: "Solanum quitoense", confidence: "high")
      expect(client).to have_received(:generate).once.with(
        a_string_including("lulo"),
        system_instruction: a_string_including("Spanish").and(a_string_including("scientific species name")),
        response_schema: described_class::RESPONSE_SCHEMA, max_tokens: 128
      )
    end

    it "falls back to the typed text when the model is not sure" do
      gemini_answer({ crop_name: "Thing", scientific_name: "", confidence: "low" }.to_json)

      expect(described_class.call(text: "my grandmother's plant", locale: :en).value)
        .to eq(crop_name: "my grandmother's plant", scientific_name: nil, confidence: "low")
    end

    it "falls back when Gemini returns nil, bad JSON or raises" do
      gemini_answer(nil)
      expect(described_class.call(text: "lulo", locale: :en).value).to include(crop_name: "lulo", confidence: "low")

      gemini_answer("not json")
      expect(described_class.call(text: "lulo", locale: :en).value).to include(scientific_name: nil, confidence: "low")

      client = instance_double(Gemini::Client)
      allow(client).to receive(:generate).and_raise(Faraday::ConnectionFailed, "down")
      allow(Gemini::Client).to receive(:new).and_return(client)
      expect(described_class.call(text: "lulo", locale: :en).value).to include(crop_name: "lulo", confidence: "low")
    end

    it "clips what it keeps to the crop name limit" do
      gemini_answer({ crop_name: "x" * 300, scientific_name: "y" * 300, confidence: "medium" }.to_json)

      value = described_class.call(text: "whatever", locale: :en).value

      expect(value[:crop_name].length).to eq(FieldCrop::NAME_MAX)
      expect(value[:scientific_name].length).to eq(FieldCrop::NAME_MAX)
    end
  end

  it "never calls Gemini while it is not configured, and still answers" do
    allow(Platform::Features).to receive(:gemini?).and_return(false)
    expect(Gemini::Client).not_to receive(:new)

    expect(described_class.call(text: "lulo", locale: :en).value).to eq(crop_name: "lulo", scientific_name: nil, confidence: "low")
  end
end
