# frozen_string_literal: true

# The NDVI layer of a field's map: Planetary Computer's data API (TiTiler)
# renders tiles of one scene with the NDVI band math, coloured red (bare) to
# green (dense crop). The browser loads them as images; the server fetches nothing.
module VegetationHelper
  TILES = "https://planetarycomputer.microsoft.com/api/data/v1/item/tiles/WebMercatorQuad/{z}/{x}/{y}@1x"
  RESCALE = "0,0.9" # the colour ramp's span: 0 bare, 0.9 the densest canopy
  COLLECTIONS = {
    "sentinel-2" => [ PlanetaryComputer::Client::COLLECTION, PlanetaryComputer::Client::NDVI ],
    "landsat" => [ PlanetaryComputer::Client::LANDSAT, PlanetaryComputer::Client::LANDSAT_NDVI ]
  }.freeze

  # A Leaflet URL template ({z}/{x}/{y} left as is) for a Fields::Vegetation::Month, or nil.
  def ndvi_tiles_url(month)
    collection, expression = COLLECTIONS[month&.mission]
    return unless collection && month.scene

    query = { collection: collection, item: month.scene, expression: expression, unscale: true,
              rescale: RESCALE, colormap_name: "rdylgn", asset_as_band: false }
    "#{TILES}?#{query.to_query}"
  end
end
