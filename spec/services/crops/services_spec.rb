require "rails_helper"

RSpec.describe "Crop services" do
  let(:user) { create(:user) }
  let!(:field) { create_farm_for(user) }

  it "plans next season as a FieldCrop and clears it" do
    expect(Crops::PlanService.call(user: user, field: field.id, crop: "medicago-sativa")).to be_success
    plan = field.field_crops.find_by(season_year: Date.current.year + 1)
    expect(plan).to have_attributes(scientific_name: "Medicago sativa", source: "farmer")

    Crops::PlanService.call(user: user, field: field.id, crop: "")
    expect(field.field_crops.where(season_year: Date.current.year + 1)).to be_empty
    expect(Crops::PlanService.call(user: user, field: create(:field).id, crop: "zea-mays").error[:code]).to eq(:not_found)
  end

  it "flags rotation rules across FieldCrop rows and names in any language" do
    seasons = [ [ "2023", "Maíz" ], [ "2024", "Corn" ], [ "2025", "zea-mays" ] ]
    expect(Crops::RotationCheck.new(seasons).findings.map(&:kind)).to eq(%w[same_family same_family monoculture])
    expect(Crops::RotationCheck.new([ [ "2024", "Soya" ], [ "2025", "Frijol" ] ]).findings.map(&:kind)).to eq(%w[same_family])
  end

  it "reads GAEZ suitability classes and attainable yield in t/ha" do
    potential = Crops::Potential.new(field.observation("gaez"))
    expect(potential.for(field.field_crops.first)).to have_attributes(suitability_class: "very_high", yield_t: 6.9)
    expect(potential.ranked.map(&:gaez)).to eq(%w[Maize Soybean Alfalfa])
    expect(potential.rows.find { |r| r.gaez == "Alfalfa" }.yield_t).to eq(12.0) # 10kg units
  end

  it "checks a crop's ECOCROP ranges against the pin's climate and the confirmed soil" do
    allow(Crops::Agronomy).to receive(:find).and_call_original
    entry = Crops::Agronomy.find("zea-mays").dup
    entry.requirements = { "topmn" => 18, "topmx" => 33, "tmin" => 10, "tmax" => 47, "ropmn" => 600, "ropmx" => 1200,
                           "rmin" => 400, "rmax" => 1800, "phopmn" => 5.5, "phopmx" => 7, "text" => "medium, light", "dra" => "well" }
    allow(Crops::Agronomy).to receive(:find).with("zea-mays").and_return(entry)

    season = Weather::Season.for(field.observation("nasa_power"))
    checks = Crops::Fit.new("zea-mays", season: season, soil: { "ph" => 6.1, "texture" => "heavy" }).checks.to_h { |c| [ c.factor, c.status ] }
    expect(checks).to eq("temperature" => :possible, "rain" => :optimal, "ph" => :optimal, "texture" => :outside, "drainage" => :unknown)
  end

  it "keeps the weather alerts the farmer wants in the profile" do
    expect(Weather::AlertsService.call(user: user, alerts: [ "", "frost" ])).to be_success
    expect(user.farmer_profile.reload.notification_preferences).to eq("weather" => %w[frost])
    expect(Weather::AlertsService.call(user: user, alerts: %w[locusts])).to be_failure
  end
end
