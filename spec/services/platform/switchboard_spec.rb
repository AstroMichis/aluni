require "rails_helper"

RSpec.describe Platform::Switchboard do
  it "is not paused by default" do
    expect(described_class.paused?(:gemini)).to be(false)
    expect { described_class.guard!(:gemini) }.not_to raise_error
  end

  it "pauses a service from its switch row and raises in guard!" do
    create(:platform_switch, service: "gemini", paused: true)
    described_class.bust!

    expect(described_class.paused?(:gemini)).to be(true)
    expect(described_class.paused?(:mail)).to be(false)
    expect { described_class.guard!(:gemini) }.to raise_error(Platform::ServicePaused) { |e| expect(e.service).to eq("gemini") }
  end

  it "pauses everything with PLATFORM_PAUSE_ALL=1, without touching the database" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("PLATFORM_PAUSE_ALL").and_return("1")
    expect(PlatformSwitch).not_to receive(:paused)

    expect(described_class.paused?(:mail)).to be(true)
  end

  it "fails open when the switch table cannot be read" do
    allow(PlatformSwitch).to receive(:paused).and_raise(ActiveRecord::StatementInvalid, "down")

    expect(described_class.paused?(:gemini)).to be(false)
  end
end
