require "rails_helper"

RSpec.describe Fields::SaveService do
  let(:user) { create(:user) }
  let!(:field) { create_farm_for(user) }

  def save(**args) = described_class.call(user: user, **args)

  it "saves a whole field form at once, through the onboarding allowlist" do
    result = save(subject: field.id, values: {
      "name" => "North 40", "irrigation" => "drip", "soil_depth" => "deep", "soil_problems" => [ "", "weeds" ],
      "planting_month" => "4", "harvest_month" => "9", "soil_ph" => "6.4"
    })

    expect(result).to be_success
    expect(field.reload).to have_attributes(name: "North 40", irrigation: "drip", soil: include("depth" => "deep", "problems" => %w[weeds], "ph" => 6.4))
    expect(field.field_crops.find_by(season_year: Date.current.year)).to have_attributes(crop_name: "Corn", planting_month: 4, harvest_month: 9)
  end

  it "leaves blank answers as they are, empties a list sent empty, and refuses values outside the vocabulary" do
    field.update!(soil: { "problems" => %w[weeds] })
    save(subject: field.id, values: { "irrigation" => "", "soil_problems" => [ "" ], "water_source" => "magic" })

    expect(field.reload).to have_attributes(irrigation: "rainfed", water_source: "rain")
    expect(field.soil["problems"]).to eq([])
  end

  it "takes the ticked suggestions: soil classes, and crop-map seasons with source cdl" do
    save(subject: field.id, confirm: %w[soil_texture soil_drainage crop_history])

    expect(field.reload.soil).to include("texture" => "medium", "drainage" => "well")
    expect(field.field_crops.where(source: "cdl").pluck(:season_year)).to contain_exactly(Date.current.year - 2, Date.current.year - 3)
  end

  it "prefers what the farmer typed over a ticked suggestion" do
    save(subject: field.id, values: { "soil_texture" => "heavy" }, confirm: %w[soil_texture])
    expect(field.reload.soil["texture"]).to eq("heavy")
  end

  it "does not rewrite a crop the farmer did not change" do
    crop = field.field_crops.find_by(season_year: Date.current.year - 1)
    crop.update!(source: "assistant")
    save(subject: field.id, values: { "crop_history" => { (Date.current.year - 1).to_s => "Soybeans" } })
    expect(crop.reload.source).to eq("assistant")
  end

  it "saves the farm profile form and moves the pin, which fetches the data again" do
    expect(save(subject: "farm", values: { "equipment" => [ "", "tractor", "harvester" ], "budget_level" => "low" })).to be_success
    expect(user.farmer_profile.reload).to have_attributes(equipment: %w[tractor harvester], budget_level: "low")

    expect { save(subject: field.id, values: { "location" => { "latitude" => "41.1", "longitude" => "-96.2" } }) }
      .to have_enqueued_job(Fields::FetchObservationsJob)
  end

  it "keeps another farmer's field out of reach" do
    expect(save(subject: create(:field).id, values: { "irrigation" => "drip" }).error[:code]).to eq(:not_found)
  end
end
