require "rails_helper"

RSpec.describe PlatformSwitch, type: :model do
  it { is_expected.to validate_inclusion_of(:service).in_array(PlatformSwitch::SERVICES) }

  it "allows one row per service" do
    create(:platform_switch, service: "gemini")
    expect(build(:platform_switch, service: "gemini")).not_to be_valid
  end

  it "lists only paused rows in .paused" do
    paused = create(:platform_switch, service: "gemini", paused: true)
    create(:platform_switch, service: "mail", paused: false)
    expect(described_class.paused).to contain_exactly(paused)
  end
end
