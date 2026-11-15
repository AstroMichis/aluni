require "rails_helper"

RSpec.describe Onboarding::SystemPrompt do
  FIXED_SNAPSHOT = <<~TEXT.strip
    FARMER: Ana
    profile.role: owner
    profile.experience: few_years
    profile.team: family
    profile.units: metric
    profile.land_tenure: unknown
    profile.budget_level: unknown
    profile.risk_tolerance: unknown
    profile.segment: unknown
    profile.team_size: unknown
    profile.goals: rotation
    profile.equipment: unknown
    profile.livestock: unknown
    profile.market_channels: unknown
    profile.practices: unknown
    farm: Finca Ana, CR
    field [ID:1] (main) North field; pin 42.0, -93.75 (confirmed); 12.5 hectares; irrigation rainfed; water rain; intensity unknown; texture=medium ph=6.1
    crop [ID:1] 2025: Corn (Zea mays), main, planted 4, harvest 10, field 1
  TEXT

  let(:snapshot) { instance_double(Onboarding::ProfileSnapshot, to_prompt: FIXED_SNAPSHOT) }
  let(:fixture) { Rails.root.join("spec/fixtures/onboarding/system_prompt.txt") }

  it "matches the golden master for a fixed snapshot" do
    prompt = described_class.build(snapshot: snapshot, topic: "soil", locale: "es", display_name: "Ana")

    expect(prompt).to eq(fixture.read.chomp), "spec/fixtures/onboarding/system_prompt.txt is stale; regenerate it from SystemPrompt.build"
  end

  it "stacks persona, lock, topic, guidance, snapshot, rules and output rules in that order" do
    prompt = described_class.build(snapshot: snapshot, topic: "location", locale: "en", display_name: "Ana")

    markers = [ "You are Aluni", "LANGUAGE LOCK", "CURRENT TOPIC: location", "REQUIRED FACTS: field.latitude", "TOPIC GUIDANCE:",
                "PROFILE SO FAR:\nFARMER: Ana", "RULES:", "OUTPUT RULES:" ]
    positions = markers.map { |m| prompt.index(m) || raise("#{m} missing") }
    expect(positions).to eq(positions.sort)
    expect(prompt).to include("ALWAYS respond in English")
    expect(prompt).not_to include("OPENING LINE")
  end

  it "adds the opening line only when given" do
    prompt = described_class.build(snapshot: snapshot, topic: "welcome", locale: "en", display_name: "Ana", opening: "Hi Ana, I am Aluni.")

    expect(prompt).to end_with("OPENING LINE ALREADY SHOWN TO THE FARMER (do not greet again):\nHi Ana, I am Aluni.")
  end
end
