require "rails_helper"

RSpec.describe Fields::AddFieldService do
  let(:answers) { { "name" => "Road field", "area" => "3", "current_crop" => "beans", "water_access" => "partial", "goals" => %w[water] } }

  it "leaves the sample behind and starts a farm at the measured point" do
    data, key = described_class.call(data: Fields::Farm.sample_data, answers: answers, confirmed: %w[soil_type season_weather]).value

    expect(data["sample"]).to be_nil
    expect(data["fields"].keys).to eq([ key ])
    expect(data.dig("fields", key)).to include("snapshot" => true, "confirmed" => %w[soil_type])
    expect(data.dig("fields", key, "answers")).to eq("name" => "Road field", "area" => 3.0, "current_crop" => "beans")
    expect(data["answers"]).to eq("water_access" => "partial", "goals" => %w[water])
    expect(data["confirmed"]).to eq(%w[season_weather])
  end

  it "adds later fields without a snapshot and without overwriting farm answers" do
    first, = described_class.call(data: Fields::Farm.sample_data, answers: answers).value
    data, key = described_class.call(data: first, answers: answers.merge("water_access" => "full", "name" => "Second")).value

    expect(key).to eq("f2")
    expect(data.dig("fields", key, "snapshot")).to be(false)
    expect(data.dig("answers", "water_access")).to eq("partial")
  end

  it "stops at the preview's limit" do
    data = { "answers" => {}, "fields" => (1..8).to_h { |n| [ "f#{n}", {} ] } }
    expect(described_class.call(data: data, answers: answers).error[:code]).to eq(:too_many)
  end
end
