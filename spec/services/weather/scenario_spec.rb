require "rails_helper"

RSpec.describe Weather::Scenario do
  let(:observation) do
    build(:field_observation, source: "nasa_power", payload: { "elevation" => 491.1, "climatology" => {
      "T2M" => { "JAN" => -4.0, "ANN" => 10.9 }, "T2M_MAX" => { "JUL" => 43.2 }, "T2M_MIN" => { "JAN" => -26.8 },
      "PRECTOTCORR" => { "JUN" => 3.6 }, "FROST_DAYS" => { "MAR" => 20.0 }, "RH2M" => { "JAN" => 70.0 } } })
  end

  it "shifts the temperatures, the rain and the frost days, and leaves the rest" do
    shifted = described_class.find("warm2_dry").apply(observation)
    climatology = shifted.payload["climatology"]

    expect(shifted).to be_ok
    expect(climatology["T2M"]).to eq("JAN" => -2.0, "ANN" => 12.9)
    expect(climatology["T2M_MAX"]).to eq("JUL" => 45.2)
    expect(climatology["PRECTOTCORR"]).to eq("JUN" => 2.88)
    expect(climatology["FROST_DAYS"]).to eq("MAR" => 10.0)
    expect(climatology["RH2M"]).to eq("JAN" => 70.0)
    expect(shifted.payload["elevation"]).to eq(491.1)
    expect(observation.payload["climatology"]["T2M"]["JAN"]).to eq(-4.0) # the record itself is untouched
  end

  it "is today's climate for an unknown key, and passes the observation through" do
    scenario = described_class.find("mars")

    expect(scenario).to be_today
    expect(scenario.apply(observation)).to be(observation)
  end
end
