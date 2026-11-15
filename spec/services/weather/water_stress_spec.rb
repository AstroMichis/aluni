require "rails_helper"

RSpec.describe Weather::WaterStress do
  # ECO_L4T_ESI at Buin, Chile, from AppEEARS (2023-11 to 2026-10, clouded readings have no ESI).
  let(:payload) { described_class.summarize(data_source_fixture("ecostress_esi_buin.csv")) }

  it "keeps the clear readings per month and the months of water stress" do
    expect(payload).to include("from" => "2023-11-22", "to" => "2026-10-17", "readings" => 69,
                               "latest" => { "date" => "2026-10-17", "esi" => 0.91 }, "source" => "NASA ECOSTRESS")
    expect(payload["stressed_months"]).to eq(%w[2025-12 2026-01 2026-02 2026-03]) # the dry Mediterranean summer
    expect(payload["normal"]["8"]).to be > 0.9
  end

  it "reads the stressed months back" do
    stress = described_class.new(build(:field_observation, source: "ecostress", payload: payload))

    expect(stress.stressed_months.map(&:month)).to eq(%w[2025-12 2026-01 2026-02 2026-03])
    expect(stress.latest).to eq("date" => "2026-10-17", "esi" => 0.91)
  end
end
