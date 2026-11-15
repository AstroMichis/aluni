require "rails_helper"

RSpec.describe Rotations::NarrateService do
  let(:facts) { { strategy: "Bring in a legume", seasons: %w[Soybeans Corn Soybeans] } }

  it "writes the why from the facts and caches it" do
    allow(Gemini::Client).to receive(:configured?).and_return(true)
    client = instance_double(Gemini::Client, generate: "Soybeans add nitrogen. Check local advice.")
    store = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(store)

    expect(described_class.call(facts: facts, locale: :en, client: client).value).to eq("Soybeans add nitrogen. Check local advice.")
    expect(described_class.call(facts: facts, locale: :en, client: client)).to be_success
    expect(client).to have_received(:generate).once
  end

  it "fails quietly when Gemini is unconfigured, paused or silent" do
    allow(Gemini::Client).to receive(:configured?).and_return(false)
    expect(described_class.call(facts: facts, locale: :es).error[:code]).to eq(:unconfigured)

    allow(Gemini::Client).to receive(:configured?).and_return(true)
    paused = instance_double(Gemini::Client)
    allow(paused).to receive(:generate).and_raise(Platform::ServicePaused.new(:gemini))
    expect(described_class.call(facts: facts, locale: :es, client: paused).error[:code]).to eq(:paused)

    silent = instance_double(Gemini::Client, generate: nil)
    expect(described_class.call(facts: facts, locale: :es, client: silent).error[:code]).to eq(:external_error)
  end
end
