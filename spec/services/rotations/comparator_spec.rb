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

  it "cites water stress (ECOSTRESS), the vegetation's normal (MODIS) and the region's water store (GRACE)" do
    record.update!(irrigation: :gravity)
    create(:field_observation, field: record, source: "ecostress", payload: {
      "months" => [ { "month" => "2026-01", "esi" => 0.2, "readings" => 3 }, { "month" => "2026-04", "esi" => 0.6, "readings" => 2 } ] })
    create(:field_observation, field: record, source: "modis", payload: {
      "normal" => { "1" => 0.4 }, "years" => 24, "below" => [ "2026-02" ] })
    create(:field_observation, field: record, source: "grace", payload: { "recent_cm" => -19.7, "trend_cm_per_decade" => -3.1 })
    current = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile).strategies.first
    facts = current.evidence.to_h { |f| [ f.key, [ f.values, f.source ] ] }

    expect(facts["water_stress"]).to eq([ { months: [ 1 ] }, "NASA ECOSTRESS" ])
    expect(facts["vegetation_below"]).to eq([ { months: [ 2 ], years: 24 }, "NASA MODIS (Terra)" ])
    expect(facts["storage_low"]).to eq([ { cm: 19.7, trend: -3.1 }, "NASA GRACE / GRACE-FO" ])
    expect(current.risks).to include("water_storage") # irrigated, and the store is depleted
  end

  it "takes the field's soil off the crop fit where a crop does not tolerate it (ECOCROP)" do
    allow(Crops::Agronomy).to receive(:find).and_call_original
    %w[glycine-max zea-mays].each do |key|
      entry = Crops::Agronomy.find(key).dup
      entry.requirements = { "dep" => "deep (>>150 cm)", "depr" => "medium (50-150 cm)", "sal" => "low (<4 dS/m)", "salr" => "low (<4 dS/m)" }
      allow(Crops::Agronomy).to receive(:find).with(key).and_return(entry)
    end
    before = comparator.strategies.first.scores["crop_fit"]

    record.update!(soil: record.soil.merge("depth" => "shallow", "salinity" => "low"))
    current = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile).strategies.first

    expect(current.scores["crop_fit"]).to eq(before - described_class::SOIL_OUTSIDE) # shallow is under the medium floor
    expect(current.evidence.find { |f| f.key == "soil_depth" }.values).to include(value: "shallow", need: "deep (>>150 cm)")
  end

  it "weighs where the irrigation water comes from" do
    record.update!(irrigation: :gravity, water_source: :unknown)
    expect(described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile).strategies.first.gaps).to include("water_source")

    record.update!(water_source: :river_canal)
    base = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile).strategies.first.scores["water"]
    create(:field_observation, field: record, source: "grace", payload: { "recent_cm" => -19.7, "trend_cm_per_decade" => -3.1 })
    current = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile).strategies.first

    expect(current.scores["water"]).to eq(base - described_class::SUPPLY_RISK)
    expect(current.evidence.map(&:key)).to include("irrigation_supply")
  end

  it "rescores under a warmer, drier climate: crops need more water than the rain gives" do
    today = comparator.strategies.first
    hot = described_class.new(field, profile: user.farmer_profile, scenario: Weather::Scenario.find("warm2_dry")).strategies.first

    need = ->(s) { s.evidence.find { |f| f.key == "water" }.values }
    expect(need.call(hot)[:need]).to be > need.call(today)[:need]
    expect(need.call(hot)[:effective]).to be < need.call(today)[:effective]
    expect(hot.scores["water"]).to be < today.scores["water"]
  end

  it "computes a crop's water need from the month the field sows it, when recorded" do
    fao_default = comparator.strategies.first.evidence.find { |f| f.key == "water" && f.values[:crop] == "glycine-max" }.values

    record.field_crops.find_by(crop_name: "Soybeans").update!(planting_month: 7)
    july = described_class.new(Fields::Farm.for(user).field(record.id), profile: user.farmer_profile).strategies.first
                          .evidence.find { |f| f.key == "water" && f.values[:crop] == "glycine-max" }.values

    expect(july[:need]).not_to eq(fao_default[:need]) # sown in July, not FAO-56's May
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

  it "shows the margin from the farmer's own harvests without scoring it, and asks for them otherwise" do
    before = comparator.strategies.first
    expect(before.gaps).to include("market")

    { "Corn" => [ "Zea mays", 11.0, 180 ], "Soybeans" => [ "Glycine max", 3.5, 400 ] }.each_with_index do |(name, (sci, amount, price)), i|
      crop = record.field_crops.find_by(scientific_name: sci) ||
             create(:field_crop, field: record, crop_name: name, scientific_name: sci, season_year: Date.current.year - 5 - i)
      crop.update!(yield_amount: amount, yield_unit: "t", area_basis: "ha", price: price, cost: 1000, currency: "USD")
    end
    current = described_class.new(field, profile: user.farmer_profile).strategies.first

    margin = current.evidence.find { |f| f.key == "margin" }
    expect(margin.values).to include(value: ((400 * 2) + 980) / 3, currency: "USD")
    expect(current.gaps).not_to include("market")
    expect(current.total).to eq(before.total)
  end
end
