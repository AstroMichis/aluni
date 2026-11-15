require "rails_helper"

RSpec.describe Fields::Farm do
  let(:user) { create(:user) }
  let!(:record) { create_farm_for(user) }
  let(:farm) { described_class.for(user) }
  let(:field) { farm.field(record.id) }

  it "reads the farmer's answers from the onboarding models" do
    expect(farm.reading("goals")).to have_attributes(state: :answered, values: { "value" => %w[rotation soil_health] })
    expect(field.reading("irrigation")).to have_attributes(state: :answered, values: { "value" => "rainfed" })
    expect(field.reading("current_crop").value).to eq("Corn")
    expect(farm.classification).to include("segment" => "mid_mechanized", "budget_level" => "high", "goals" => "rotation")
  end

  it "proposes what a source says for the farmer to confirm, in the onboarding vocabulary" do
    reading = field.reading("soil_texture")

    expect(reading.state).to eq(:to_confirm)
    expect(reading.values).to eq("sand" => 13.0, "clay" => 24.0)
    expect(reading.proposal).to eq("medium")
    expect(reading.source.id).to eq("ssurgo")
    expect(field.reading("soil_drainage").proposal).to eq("well")
  end

  it "shows source values with their scale and confidence" do
    slope = field.reading("slope")
    expect([ slope.state, slope.value, slope.source.id, slope.confidence ]).to eq([ :auto, 1.2, "usgs_3dep", "high" ])

    rain = field.reading("rain_normal")
    expect(rain.value).to be_within(0.1).of(1.98 * 365)
    expect(rain.confidence).to eq("low") # regional context
  end

  it "tells pending, failed, missing pin and gaps apart" do
    bare = described_class::Field.new(create(:field, :unlocated, farm: record.farm), profile: farm.profile)
    expect(bare.reading("slope").state).to eq(:needs_pin)

    record.observations.find_by(source: "usgs_elevation").update!(status: :failed, payload: {})
    expect(described_class.for(user).field(record.id).reading("slope").state).to eq(:failed)

    record.observations.find_by(source: "usgs_elevation").destroy!
    expect(described_class.for(user).field(record.id).reading("slope").state).to eq(:pending)

    elsewhere = create(:field, farm: record.farm, latitude: 9.93, longitude: -84.08)
    observe(elsewhere, us: false)
    global = described_class.for(user).field(elsewhere.id)
    expect(global.layer).to eq("global")
    expect(global.reading("soil_series").state).to eq(:gap)
    expect(global.reading("soil_texture").state).to eq(:unanswered) # asked outside the US
    expect(global.reading("slope").state).to eq(:pending) # 3DEP out of coverage, NASADEM not asked yet
  end

  it "falls back to NASADEM for the slope where 3DEP has none" do
    elsewhere = create(:field, farm: record.farm, latitude: -41.32, longitude: -72.98)
    observe(elsewhere, us: false)
    create(:field_observation, field: elsewhere, source: "nasadem", payload: { "elevation" => 74.0, "slope" => 3.2 })
    global = described_class.for(user).field(elsewhere.id)

    slope = global.reading("slope")
    expect([ slope.state, slope.value, slope.source.id ]).to eq([ :auto, 3.2, "srtm" ])
    expect(global.reading("elevation").value).to eq(74.0)

    # In the US both answer and the lidar wins.
    create(:field_observation, field: record, source: "nasadem", payload: { "elevation" => 490.0, "slope" => 9.9 })
    expect(described_class.for(user).field(record.id).reading("slope").source.id).to eq("usgs_3dep")
  end

  it "keeps the crop seasons, the plan and the CDL years not recorded yet" do
    create(:field_crop, field: record, crop_name: "Oats", scientific_name: "Avena sativa", season_year: Date.current.year + 1)
    field = described_class.for(user).field(record.id)

    expect(field.history.keys).to eq([ (Date.current.year - 1).to_s, Date.current.year.to_s ])
    expect(field.plan.crop_name).to eq("Oats")
    expect(field.seasons.last.first).to eq("plan")
    expect(field.cdl_proposal.keys).to contain_exactly((Date.current.year - 2).to_s, (Date.current.year - 3).to_s)
  end

  it "asks only for the essentials: the to-do list and progress count nothing else" do
    record.update!(irrigation: :unknown)
    field = described_class.for(user).field(record.id)

    expect(field.todo.map { |r| r.datum.key }).to eq(%w[irrigation])
    expect(field.progress).to eq([ 3, 4 ]) # pin, crop and history answered; watering missing
    expect(field.todo.map { |r| r.datum.key }).not_to include("soil_depth", "name")
  end
end
