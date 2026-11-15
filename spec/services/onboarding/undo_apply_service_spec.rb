require "rails_helper"

# Undo puts back what ApplyProposalService captured. The before hash goes
# through the jsonb column first, the way ReplyService stores it, so decimals
# and enums come back as the database returns them.
RSpec.describe Onboarding::UndoApplyService do
  let(:user) { create(:user) }
  let(:rows) { Onboarding::EnsureProfileService.call(user: user).value }
  let(:session) { rows[:session] }
  let(:field) { rows[:field] }

  def apply!(proposal)
    session.update!(proposal: proposal)
    result = Onboarding::ApplyProposalService.call(user: user, accepted: Onboarding::Allowlist.keys_for(proposal))
    session.update!(last_applied: { "before" => result.value[:before], "applied" => result.value[:applied], "at" => Time.current.iso8601 })
    session.reload
  end

  it "restores profile, farm and field attributes, the old soil hash and the crops, then clears last_applied" do
    rows[:profile].update!(budget_level: :high, goals: %w[yield])
    rows[:farm].update!(name: "Old name")
    field.update!(area: 3, area_unit: :acres, soil: { "ph" => 6.5, "texture" => "heavy" })
    kept = create(:field_crop, field: field, season_year: 2024, role: :main, crop_name: "Soy", scientific_name: "Glycine max", planting_month: 5, harvest_month: 10, source: :farmer)
    apply!(
      "profile" => { "budget_level" => "low", "goals" => %w[rotation] },
      "farm" => { "name" => "Finca Ana" },
      "field" => { "area" => 12.5, "area_unit" => "hectares", "soil" => { "texture" => "medium", "drainage" => "well" } },
      "crops" => [ { "season_year" => 2025, "role" => "main", "crop_name" => "Corn", "scientific_name" => "Zea mays" },
                   { "season_year" => 2024, "role" => "main", "crop_name" => "Beans", "scientific_name" => "Phaseolus vulgaris" } ]
    )
    expect(field.reload).to have_attributes(area: 12.5, area_unit: "hectares", soil: { "ph" => 6.5, "texture" => "medium", "drainage" => "well" })
    expect(field.field_crops.count).to eq(2)

    result = described_class.call(user: user)

    expect(result).to be_success
    expect(result.value[:restored]).to include(
      "profile.budget_level" => "high", "profile.goals" => [ "yield" ], "farm.name" => "Old name",
      "field.area_unit" => "acres", "field.soil" => { "ph" => 6.5, "texture" => "heavy" }, "crops.2025.main" => nil
    )
    expect(result.value[:restored]["field.area"].to_d).to eq(3)
    expect(result.value[:restored]["crops.2024.main"]).to include("crop_name" => "Soy", "source" => "farmer")

    expect(user.farmer_profile.reload).to have_attributes(budget_level: "high", goals: [ "yield" ])
    expect(rows[:farm].reload.name).to eq("Old name")
    expect(field.reload).to have_attributes(area: 3, area_unit: "acres", soil: { "ph" => 6.5, "texture" => "heavy" })
    expect(field.field_crops.count).to eq(1)
    expect(kept.reload).to have_attributes(crop_name: "Soy", scientific_name: "Glycine max", planting_month: 5, harvest_month: 10, source: "farmer")
    expect(session.reload.last_applied).to eq({})
  end

  it "restores a field that was empty before, including an empty soil hash" do
    apply!("field" => { "area" => 12.5, "irrigation" => "drip", "soil" => { "texture" => "medium" } })
    expect(field.reload).to have_attributes(area: 12.5, irrigation: "drip", soil: { "texture" => "medium" })

    result = described_class.call(user: user)

    expect(result).to be_success
    expect(field.reload).to have_attributes(area: nil, irrigation: "unknown", soil: {})
    expect(result.value[:restored]).to include("field.area" => nil, "field.irrigation" => "unknown", "field.soil" => {})
  end

  it "has nothing to undo on a fresh session and after an undo" do
    expect(described_class.call(user: user).error).to include(code: :nothing_to_undo)

    apply!("profile" => { "budget_level" => "low" })
    expect(described_class.call(user: user)).to be_success
    expect(described_class.call(user: user).error).to include(code: :nothing_to_undo)
    expect(user.farmer_profile.reload.budget_level).to eq("unknown")
  end

  it "ignores a last_applied without a usable before" do
    session.update!(last_applied: { "applied" => { "profile.budget_level" => "low" }, "at" => Time.current.iso8601 })

    expect(described_class.call(user: user).error).to include(code: :nothing_to_undo)
  end

  it "rolls everything back and keeps last_applied when one write is invalid" do
    apply!("profile" => { "budget_level" => "low" }, "field" => { "area" => 12.5 })
    field.update_columns(position: -1)

    result = described_class.call(user: user)

    expect(result.error).to include(code: :invalid)
    expect(user.farmer_profile.reload.budget_level).to eq("low")
    expect(session.reload.last_applied["before"]).to be_present
  end
end
