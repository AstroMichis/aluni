require "rails_helper"

RSpec.describe Onboarding::AreaImage do
  it "builds a GIBS WMS GetMap URL with the bbox in lat,lon order around the pin" do
    url = described_class.url(latitude: 42.0, longitude: -93.75)
    query = Rack::Utils.parse_query(URI(url).query)

    expect(url).to start_with("https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi?")
    expect(query).to include("SERVICE" => "WMS", "VERSION" => "1.3.0", "REQUEST" => "GetMap", "CRS" => "EPSG:4326",
                             "LAYERS" => "BlueMarble_NextGeneration", "FORMAT" => "image/jpeg", "WIDTH" => "512", "HEIGHT" => "512")
    expect(query["BBOX"]).to eq("41.7500,-94.0000,42.2500,-93.5000")
    expect(query).not_to have_key("TIME")
  end

  it "adds TIME for the daily layer and clamps near the poles" do
    url = described_class.url(latitude: 89.9, longitude: 179.9, span: 1, size: 256, layer: described_class::DAILY_LAYER, time: Date.new(2025, 7, 4))
    query = Rack::Utils.parse_query(URI(url).query)

    expect(query).to include("TIME" => "2025-07-04", "LAYERS" => "MODIS_Terra_CorrectedReflectance_TrueColor", "WIDTH" => "256")
    expect(query["BBOX"]).to eq("89.0000,179.0000,90.0000,180.0000")
  end
end
