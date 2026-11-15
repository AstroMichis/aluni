require "rails_helper"

RSpec.describe VegetationHelper do
  def month(mission, scene) = Fields::Vegetation::Month.new(month: "2026-11", ndvi: 0.4, mission: mission, scene: scene, date: "2026-11-08")

  it "builds the NDVI tile template of the scene, leaving {z}/{x}/{y} for Leaflet" do
    url = helper.ndvi_tiles_url(month("sentinel-2", "S2C_MSIL2A_X"))

    expect(url).to start_with("https://planetarycomputer.microsoft.com/api/data/v1/item/tiles/WebMercatorQuad/{z}/{x}/{y}@1x?")
    query = Rack::Utils.parse_query(url.split("?", 2).last)
    expect(query).to include("collection" => "sentinel-2-l2a", "item" => "S2C_MSIL2A_X", "expression" => PlanetaryComputer::Client::NDVI,
                             "unscale" => "true", "colormap_name" => "rdylgn")
    expect(Rack::Utils.parse_query(helper.ndvi_tiles_url(month("landsat", "LC09_X")).split("?", 2).last))
      .to include("collection" => "landsat-c2-l2", "expression" => PlanetaryComputer::Client::LANDSAT_NDVI)
  end

  it "has no layer without a scene" do
    expect(helper.ndvi_tiles_url(month("sentinel-2", nil))).to be_nil
    expect(helper.ndvi_tiles_url(nil)).to be_nil
  end
end
