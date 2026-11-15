require "rails_helper"

RSpec.describe Crops::PlanService do
  let(:data) { Fields::Farm.sample_data }

  it "sets and clears a plan, and refuses unknown fields or crops" do
    expect(described_class.call(data: data, field: "creek", crop: "oats").value["plans"]).to eq("north" => "soybeans", "creek" => "oats")
    expect(described_class.call(data: data, field: "north", crop: "").value["plans"]).to eq({})
    expect(described_class.call(data: data, field: "nowhere", crop: "oats").error[:code]).to eq(:not_found)
    expect(described_class.call(data: data, field: "creek", crop: "kale")).to be_failure
  end
end
