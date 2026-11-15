require "rails_helper"

RSpec.describe Fields::Farm do
  subject(:farm) { described_class.build(described_class.sample_data) }

  it "builds the sample farm, its fields and the classification" do
    expect(farm).to be_sample
    expect(farm.fields.map(&:key)).to eq(%w[north creek home])
    expect(farm.total_area).to be_within(0.01).of(56.7)
    expect(farm.classification).to eq("size" => "large", "water" => "rainfed", "inputs" => "medium", "goal" => "soil", "tech" => "intermediate")
    expect(farm.period).to eq([ Date.new(2025, 1, 1), Date.new(2025, 10, 31) ])
  end

  it "reads measured values from the snapshot with the source that produced them" do
    reading = farm.field(:north).reading("slope")

    expect([ reading.state, reading.value ]).to eq([ :auto, 4.05 ])
    expect([ reading.source.id, reading.confidence ]).to eq(%w[usgs_3dep high])
    expect(farm.reading("season_weather").confidence).to eq("low")
  end

  it "tells answered, to-confirm, confirmed, pending and unanswered data apart" do
    north = farm.field(:north)
    expect(farm.reading("water_access").state).to eq(:answered)
    expect(north.reading("soil_texture").state).to eq(:to_confirm)
    expect(north.reading("soil_type").state).to eq(:confirmed)
    expect(farm.field(:creek).reading("slope").state).to eq(:pending)
    expect(farm.field(:home).reading("current_crop").state).to eq(:unanswered)
  end

  it "lists what is left to do and how far each field has come" do
    home = farm.field(:home)
    expect(home.todo.map { |r| r.datum.key }).to include("current_crop")
    expect(home.todo.map { |r| r.datum.key }).not_to include("name", "soil_test", "field_notes") # optional
    done, total = farm.field(:north).progress
    expect(done).to be < total
  end

  it "takes the crop history from the crop map or from the person" do
    expect(farm.field(:north).history.values.last(2)).to eq(%w[soybeans corn])
    expect(farm.field(:creek).history).to eq("2023" => "corn", "2024" => "soybeans", "2025" => "soybeans")
    expect(farm.field(:home).history).to eq({})
  end

  it "asks a farm step again only while it has unanswered farm data" do
    water = Fields::Profile.current.steps.find { |s| s.key == "water" }
    own = described_class.build({ "answers" => { "water_access" => "full" }, "fields" => {} })
    expect(own.needs?(water)).to be(false)
    expect(described_class.build({ "answers" => {}, "fields" => {} }).needs?(water)).to be(true)
  end
end
