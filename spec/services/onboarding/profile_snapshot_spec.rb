require "rails_helper"

RSpec.describe Onboarding::ProfileSnapshot do
  let(:user) { create(:user, display_name: "Ana") }

  it "is empty but well-formed before onboarding starts" do
    snapshot = described_class.new(user: user)

    expect(snapshot.to_h).to include(profile: nil, farm: nil, field: nil, fields: [], crops: [], session: nil)
    expect(snapshot.to_prompt).to include("FARMER: Ana").and include("fields: none yet").and include("crops: none recorded")
    expect(snapshot.required_known?(%w[field.latitude])).to be(false)
    expect(snapshot.completeness).to eq(0.0)
  end

  it "turns unknown enums into nil for the preview and 'unknown' for the prompt" do
    create(:farmer_profile, :blank, user: user, budget_level: :high)
    snapshot = described_class.new(user: user)

    expect(snapshot.to_h[:profile]).to include(role: nil, budget_level: "high", goals: [])
    expect(snapshot.to_prompt).to include("profile.role: unknown").and include("profile.budget_level: high").and include("profile.goals: unknown")
  end

  it "lists fields and crops with ID markers the model can target" do
    farm = create(:farm, user: user, name: "Finca Ana", country_code: "CR")
    field = create(:field, farm: farm, soil: { "texture" => "medium", "ph" => 6.1 })
    crop = create(:field_crop, field: field)
    snapshot = described_class.new(user: user)

    expect(snapshot.to_prompt).to include("farm: Finca Ana, CR")
      .and include("field [ID:#{field.id}] (main) North field; pin 42.0, -93.75 (confirmed); 12.5 hectares")
      .and include("texture=medium").and include("ph=6.1")
      .and include("crop [ID:#{crop.id}] 2025: Corn (Zea mays), main, planted 4, harvest 10")
    expect(snapshot.to_h[:field]).to include(latitude: 42.0, irrigation: "rainfed", area_unit: "hectares")
    expect(snapshot.required_known?(%w[field.latitude field.area field.irrigation field.soil.texture crops])).to be(true)
    expect(snapshot.required_known?(%w[field.soil.drainage])).to be(false)
    expect(snapshot.completeness).to be_within(0.01).of(0.5)
  end
end
