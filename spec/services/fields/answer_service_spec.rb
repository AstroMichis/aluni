require "rails_helper"

RSpec.describe Fields::AnswerService do
  let(:data) { Fields::Farm.sample_data }

  it "confirms an inferred value without touching the original data" do
    result = described_class.call(data: data, subject: "north", datum: "soil_texture", confirm: true)

    expect(result.value.dig("fields", "north", "confirmed")).to include("soil_texture")
    expect(data.dig("fields", "north", "confirmed")).not_to include("soil_texture")
  end

  it "keeps options, lists, areas, histories and short text, and refuses the rest" do
    ok = ->(subject, datum, value) { described_class.call(data: data, subject: subject, datum: datum, value: value) }

    expect(ok.call("farm", "machinery", %w[tractor harvester]).value.dig("answers", "machinery")).to eq(%w[tractor harvester])
    expect(ok.call("home", "area", "7.25").value.dig("fields", "home", "answers", "area")).to eq(7.25)
    expect(ok.call("home", "crop_history", { "2025" => "corn", "x" => "corn", "2024" => "kale" }).value.dig("fields", "home", "answers", "crop_history")).to eq("2025" => "corn")
    expect(ok.call("home", "field_notes", "Wet corner").value.dig("fields", "home", "answers", "field_notes")).to eq("Wet corner")

    expect(ok.call("farm", "water_access", "lots")).to be_failure
    expect(ok.call("home", "area", "-3")).to be_failure
    expect(ok.call("home", "field_notes", "x" * 201)).to be_failure
    expect(ok.call("nowhere", "area", "1").error[:code]).to eq(:not_found)
    expect(ok.call("farm", "area", "1").error[:code]).to eq(:not_found) # a field datum on the farm
  end
end
