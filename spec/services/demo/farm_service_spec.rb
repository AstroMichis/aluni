require "rails_helper"

RSpec.describe Demo::FarmService do
  let(:user) { create(:user) }

  it "fills a signed-up account with the Chilean sample farm, ready for the plan" do
    result = described_class.call(user: user, preset: "chile")

    field = result.value
    expect(result).to be_success
    expect(user.reload).to have_attributes(locale: "es", onboarding_complete?: true)
    expect(user.farmer_profile).to have_attributes(risk_tolerance: "cautious", market_channels: %w[local_market contract])
    expect(field).to have_attributes(name: "Potrero Sur", irrigation: "gravity", located?: true)
    expect(field.field_crops.find_by(season_year: Date.current.year).scientific_name).to eq("Zea mays")
    expect(field.field_crops.count).to eq(4)

    comparator = Rotations::Comparator.new(Fields::Farm.for(user).field(field.id), profile: user.farmer_profile)
    expect(comparator).to be_ready
    expect(comparator.strategies.drop(1).flat_map(&:risks)).to include("contract", "new_crop")
  end

  it "replaces only its own farm when run again, and lets the new pin fetch its data" do
    described_class.call(user: user, preset: "nebraska")

    expect { described_class.call(user: user, preset: "nebraska") }
      .to have_enqueued_job(Fields::FetchObservationsJob)
    expect(user.farms.pluck(:name)).to eq([ "Prairie View Farm" ])
  end

  it "records the cover crop in the Nebraska history" do
    field = described_class.call(user: user, preset: "nebraska").value

    expect(field.field_crops.where(role: :cover).pluck(:crop_name, :season_year)).to eq([ [ "Cereal rye", Date.current.year - 1 ] ])
  end

  it "refuses an account that has its own farms unless forced" do
    create(:farm, user: user, name: "Real farm")

    expect(described_class.call(user: user, preset: "nebraska").error).to include(code: :has_farms, count: 1)
    expect(described_class.call(user: user, preset: "nebraska", force: true)).to be_success
    expect(described_class.call(user: user, preset: "mars").error).to include(code: :unknown_preset)
  end
end
