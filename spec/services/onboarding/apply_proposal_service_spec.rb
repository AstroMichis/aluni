require "rails_helper"

RSpec.describe Onboarding::ApplyProposalService do
  let(:user) { create(:user) }
  let(:rows) { Onboarding::EnsureProfileService.call(user: user).value }
  let(:session) { rows[:session] }
  let(:field) { rows[:field] }
  let(:proposal) do
    {
      "profile" => { "budget_level" => "low", "goals" => %w[rotation moon], "role" => "king" },
      "farm" => { "name" => "Finca Ana" },
      "field" => { "area" => 12.5, "area_unit" => "hectares", "soil" => { "texture" => "medium", "ph" => 6.1, "colour" => "red" } },
      "crops" => [ { "season_year" => 2025, "role" => "main", "crop_name" => "Corn", "scientific_name" => "Zea mays",
                     "planting_month" => 4, "harvest_month" => 10 } ]
    }
  end

  before { session.update!(proposal: proposal) }

  it "applies only the accepted keys, re-filtered through the allowlist, and clears the proposal" do
    accepted = %w[profile.budget_level profile.goals profile.role field.area field.soil.texture crops.2025.main]

    result = described_class.call(user: user, accepted: accepted)

    expect(result).to be_success
    expect(result.value[:applied].keys).to contain_exactly("profile.budget_level", "profile.goals", "field.area", "field.soil.texture", "crops.2025.main")
    expect(result.value[:applied]["profile.goals"]).to eq([ "rotation" ])
    expect(result.value[:applied]["crops.2025.main"]).to include("crop_name" => "Corn")

    profile = user.farmer_profile.reload
    expect(profile.budget_level).to eq("low")
    expect(profile.goals).to eq([ "rotation" ])
    expect(profile.role).to eq("unknown")
    expect(rows[:farm].reload.name).to eq("")
    expect(field.reload.area).to eq(12.5)
    expect(field.area_unit).to eq("hectares")
    expect(field.soil).to eq("texture" => "medium")
    crop = field.field_crops.sole
    expect(crop).to have_attributes(crop_name: "Corn", scientific_name: "Zea mays", season_year: 2025, role: "main", planting_month: 4, source: "assistant")
    expect(session.reload.proposal).to eq({})
  end

  it "merges soil into what the field already knows" do
    field.update!(soil: { "ph" => 6.5, "texture" => "heavy" })
    session.update!(proposal: { "field" => { "soil" => { "texture" => "medium", "drainage" => "well" } } })

    described_class.call(user: user, accepted: %w[field.soil.texture field.soil.drainage])

    expect(field.reload.soil).to eq("ph" => 6.5, "texture" => "medium", "drainage" => "well")
  end

  it "upserts crops by season and role" do
    existing = create(:field_crop, field: field, season_year: 2025, role: :main, crop_name: "Corn", source: :farmer)
    session.update!(proposal: { "crops" => [ { "season_year" => 2025, "role" => "main", "crop_name" => "Soy", "scientific_name" => "Glycine max" } ] })

    expect { described_class.call(user: user, accepted: %w[crops.2025.main]) }.not_to change(FieldCrop, :count)
    expect(existing.reload).to have_attributes(crop_name: "Soy", scientific_name: "Glycine max", source: "assistant")
  end

  it "applies the pin as one fact" do
    session.update!(proposal: { "field" => { "latitude" => 9.93, "longitude" => -84.08, "location_confidence" => "approximate",
                                             "location_source" => "assistant", "place_label" => "Cartago", "area" => 3 } })

    result = described_class.call(user: user, accepted: %w[field.latitude])

    expect(result.value[:applied].keys).to contain_exactly("field.latitude", "field.longitude", "field.location_confidence", "field.location_source", "field.place_label")
    expect(field.reload).to have_attributes(latitude: 9.93, longitude: -84.08, location_confidence: "approximate", location_source: "assistant", place_label: "Cartago", area: nil)
  end

  it "rolls everything back when one write is invalid" do
    field.update_columns(position: -1)

    result = described_class.call(user: user, accepted: %w[profile.budget_level field.area])

    expect(result.error).to include(code: :invalid)
    expect(result.error[:messages]).to be_present
    expect(user.farmer_profile.reload.budget_level).to eq("unknown")
    expect(session.reload.proposal).to eq(proposal)
  end

  it "is expired when nothing is staged" do
    session.update!(proposal: {})

    expect(described_class.call(user: user, accepted: %w[profile.budget_level]).error).to include(code: :expired)
  end

  it "applies nothing but clears the proposal when nothing is accepted" do
    result = described_class.call(user: user, accepted: [])

    expect(result.value).to eq(applied: {})
    expect(session.reload.proposal).to eq({})
    expect(user.farmer_profile.reload.budget_level).to eq("unknown")
  end
end
