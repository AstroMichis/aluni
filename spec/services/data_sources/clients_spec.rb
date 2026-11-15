require "rails_helper"

RSpec.describe "Public data source clients" do
  let(:point) { { latitude: 40.95, longitude: -97.50 } }

  it "reads NASA POWER daily values and normals, dropping the -999 fill" do
    stub_power(daily: { "T2M" => { "20260101" => -4.1, "20260102" => -999.0 } })
    client = NasaPower::Client.new

    expect(client.daily(**point, from: Date.new(2026, 1, 1), to: Date.new(2026, 1, 2))).to eq("T2M" => { "20260101" => -4.1, "20260102" => nil })
    expect(client.climatology(**point).dig("FROST_DAYS", "ANN")).to eq(136.2)
    expect(a_request(:get, /daily\/point/).with(query: hash_including("community" => "AG", "start" => "20260101"))).to have_been_made
  end

  it "finds GAEZ layers per crop and reads a pixel" do
    stub_gaez
    client = Gaez::Client.new

    layers = client.layers(crops: %w[Maize Soybean], input_level: "High")
    expect(layers["Maize"]).to eq("yield" => 258632, "yield_units" => "kg DW/ha", "suitability" => 257854)
    expect(client.value(**point, objectid: 258632)).to eq(6867.0)
  end

  it "reads the SSURGO topsoil of the dominant component, numbers as numbers" do
    stub_us_layer
    soil = Ssurgo::Client.new.soil(**point)
    expect(soil).to include("compname" => "Hastings", "drainagecl" => "Well drained", "om_r" => 3.0, "claytotal_r" => 24.0)
  end

  it "derives elevation and slope from USGS 3DEP" do
    stub_us_layer
    expect(Usgs::ElevationClient.new.terrain(**point)).to eq("elevation" => 321.7, "slope" => 0.0)
  end

  it "converts the pin to Albers and reads the CDL crop per year" do
    stub_us_layer
    expect(Cdl::Client.albers(40.95, -97.50).map { |v| v.round(1) }).to eq([ -125249.1, 1994380.6 ])
    expect(Cdl::Client.new.history(**point, years: [ 2025 ])).to eq("2025" => "Corn")
  end

  it "places a US pin and returns nothing outside the US" do
    stub_fcc(us: true)
    expect(Fcc::Client.new.locate(**point)).to include("state_code" => "NE", "county" => "York County")
    stub_fcc(us: false)
    expect(Fcc::Client.new.locate(latitude: 9.93, longitude: -84.08)).to eq({})
  end

  it "raises one error class on HTTP errors and refuses while the data switch is paused" do
    stub_request(:get, %r{geo\.fcc\.gov}).to_return(status: 404)
    expect { Fcc::Client.new.locate(**point) }.to raise_error(DataSources::Client::Error)

    allow(Platform::Switchboard).to receive(:paused?).and_call_original
    allow(Platform::Switchboard).to receive(:paused?).with(:data).and_return(true)
    expect { Fcc::Client.new.locate(**point) }.to raise_error(Platform::ServicePaused)
  end
end
