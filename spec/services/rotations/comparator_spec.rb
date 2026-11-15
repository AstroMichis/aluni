require "rails_helper"

RSpec.describe Rotations::Comparator do
  let(:user) { create(:user) }
  let!(:record) { create_farm_for(user) }
  let(:field) { Fields::Farm.for(user).field(record.id) }
  let(:comparator) { described_class.new(field, profile: user.farmer_profile) }

  it "compares the current rotation with at least two alternatives over the next three seasons" do
    keys = comparator.strategies.map(&:key)

    expect(keys.first).to eq("current")
    expect(keys.size).to be >= 3
    expect(comparator.strategies.first.crops).to eq(%w[glycine-max zea-mays glycine-max]) # soy, corn alternating
    expect(comparator.strategies).to all(have_attributes(crops: satisfy { |c| c.size == 3 }))
  end

  it "scores with the field's data and weighs the farmer's goals" do
    expect(comparator.weights).to include("pest_break" => 3, "soil_health" => 3, "water" => 1) # goals: rotation, soil_health
    grain = comparator.strategies.find { |s| s.key == "small_grain" }

    expect(grain.crops).to eq(%w[triticum-aestivum glycine-max zea-mays]) # corn-soy-wheat
    expect(grain.scores["crop_fit"]).to eq(82) # Soybean 7600 and Maize 8700 at the pin; wheat not in GAEZ here
    expect(grain.gaps).to include("suitability")
    expect(grain.scores["nitrogen"]).to eq(33)
    expect(grain.scores["water"]).to be_between(1, 100)
    expect(grain.evidence.map(&:key)).to include("suitability", "water", "slope")
    expect(comparator.strategies.map(&:key)).not_to include("legume") # the rotation already has soybeans
  end

  it "takes the slope from NASADEM where the US lidar has none" do
    record.observations.find_by(source: "usgs_elevation").update!(status: :out_of_coverage, payload: {})
    create(:field_observation, field: record, source: "nasadem", payload: { "elevation" => 74.0, "slope" => 7.5 })
    slope = comparator.strategies.first.evidence.find { |f| f.key == "slope" }

    expect([ slope.source, slope.values ]).to eq([ "NASA NASADEM", { value: 7.5 } ])
    expect(comparator.strategies.first.gaps).not_to include("slope")
  end

  it "weighs how often it pours (GPM IMERG) into the erosion of row crops" do
    current = comparator.strategies.first
    expect(current.evidence.map(&:key)).not_to include("heavy_rain", "heavy_rain_rare")
    calm = current.scores["erosion"]

    months = (1..12).map { |m| { "month" => m, "heavy_days" => m.between?(5, 7) ? 2.5 : 0.2, "extreme_days" => m == 6 ? 1.2 : 0.0 } }
    create(:field_observation, field: record, source: "gpm_imerg",
                               payload: { "years" => 20, "heavy_days_per_year" => 8.1, "extreme_days_per_year" => 1.2, "months" => months })
    stormy = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile).strategies.first

    rain = stormy.evidence.find { |f| f.key == "heavy_rain" }
    expect([ rain.values, rain.source ]).to eq([ { days: 8.1, years: 20, months: [ 5, 6, 7 ] }, "NASA GPM IMERG" ])
    expect(stormy.risks).to include("heavy_rain") # soy and corn are row crops
    expect(stormy.scores["erosion"]).to eq(calm - (3 * described_class::STORM_PENALTY))
  end

  it "cites the last year's soil moisture (SMAP) and warns a rainfed field after dry months" do
    record.update!(irrigation: :rainfed)
    months = %w[2026-01 2026-02 2026-03 2026-04].each_with_index.map { |m, i| { "month" => m, "rootzone" => 0.1, "pctl" => i < 3 ? 12 : 55 } }
    create(:field_observation, field: record, source: "smap", payload: { "months" => months, "latest" => { "pctl" => 55 } })
    current = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile).strategies.first

    soil = current.evidence.find { |f| f.key == "soil_dry" }
    expect([ soil.values, soil.source ]).to eq([ { months: [ 1, 2, 3 ] }, "NASA SMAP L4" ])
    expect(current.risks).to include("dry_soil")
  end

  it "cites the second crop the field grows, and the gap when two crops a year are not recorded" do
    record.update!(cropping_intensity: :two_per_year)
    comparator = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile)
    expect(comparator.strategies.first.gaps).to include("second_crop")

    create(:field_crop, field: record, role: :second, crop_name: "Wheat", scientific_name: "Triticum aestivum", season_year: Date.current.year - 1)
    current = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile).strategies.first

    expect(current.evidence.find { |f| f.key == "double_crop" }.values).to eq(main: "glycine-max", second: "triticum-aestivum")
    expect(current.gaps).not_to include("second_crop")
  end

  it "cites the cover crops the field already had" do
    create(:field_crop, field: record, role: :cover, crop_name: "Cereal rye", scientific_name: "Secale cereale", season_year: Date.current.year - 1)
    current = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile).strategies.first

    expect(current.evidence.find { |f| f.key == "cover_history" }.values).to eq(crops: "Cereal rye", years: (Date.current.year - 1).to_s)
  end

  it "says what is better than now, what is unknown and what to check locally" do
    alternative = comparator.strategies.drop(1).first
    expect(alternative.gaps).to include("market", "soil")
    expect(alternative.risks).to be_an(Array)
    expect(comparator.strategies.drop(1).flat_map(&:benefits)).not_to be_empty
  end

  it "counts conservation practices as the soil health goal" do
    user.farmer_profile.update!(goals: [], practices: [ "no_till" ])

    expect(comparator.weights).to include("soil_health" => 3, "nitrogen" => 3, "erosion" => 3, "pest_break" => 1)
  end

  it "flags new crops for a cautious farmer and for contract sales, never on the current rotation" do
    user.farmer_profile.update!(risk_tolerance: :cautious, market_channels: [ "contract" ])

    current, *others = comparator.strategies
    expect(current.risks).not_to include("new_crop", "contract")
    flagged = others.select { |s| s.risks.include?("new_crop") }
    expect(flagged).not_to be_empty
    expect(flagged).to all(have_attributes(risks: include("contract")))
  end

  it "says nothing about new crops for a farmer open to change" do
    user.farmer_profile.update!(risk_tolerance: :bold, market_channels: [ "local_market" ])

    expect(comparator.strategies.flat_map(&:risks)).not_to include("new_crop", "contract")
  end

  it "still offers three strategies when the current crop is already a legume" do
    record.field_crops.find_by(season_year: Date.current.year).update!(crop_name: "Soybeans", scientific_name: "Glycine max")
    comparator = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile)
    expect(comparator.strategies.size).to be >= 3
    expect(comparator.strategies.map(&:key)).not_to include("legume")
  end

  it "waits for this season's crop" do
    record.field_crops.destroy_all
    comparator = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile)
    expect(comparator).not_to be_ready
    expect(comparator.strategies).to be_empty
  end
end
