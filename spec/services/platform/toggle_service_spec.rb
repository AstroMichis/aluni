require "rails_helper"

RSpec.describe Platform::ToggleService do
  it "pauses a service and records who did it" do
    result = described_class.call(service: :gemini, paused: true, reason: "quota", actor: "luis")

    expect(result).to be_success
    switch = result.value
    expect(switch).to have_attributes(service: "gemini", paused: true, reason: "quota", paused_by: "luis")
    expect(Platform::Switchboard.paused?(:gemini)).to be(true)
  end

  it "resumes a paused service" do
    create(:platform_switch, service: "mail", paused: true)

    result = described_class.call(service: :mail, paused: false)

    expect(result).to be_success
    expect(result.value.paused).to be(false)
    expect(Platform::Switchboard.paused?(:mail)).to be(false)
  end

  it "syncs sidekiq-cron when the cron or jobs switch changes" do
    allow(Platform::CronControl).to receive(:sync!)

    described_class.call(service: :cron, paused: true)
    described_class.call(service: :gemini, paused: true)

    expect(Platform::CronControl).to have_received(:sync!).once
  end

  it "fails on an unknown service" do
    result = described_class.call(service: :fax, paused: true)

    expect(result).to be_failure
    expect(result.error[:code]).to eq(:invalid)
  end
end
