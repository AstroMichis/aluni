# The public glossary: each term the plan and the field pages use, in plain
# words, the dataset that measures it, at what scale, and what it cannot tell.
# The evidence sources on Your plan link to its entries (RotationsHelper).
class GlossaryController < ApplicationController
  allow_unauthenticated_access
  layout "public"

  TERMS = %w[ndvi vegetation_normal evapotranspiration water_need soil_moisture water_stress water_storage
             heavy_rain slope suitability requirements climate_normals percentile scenario].freeze
  # The source labels on evidence lines (Fact#source) and the term that explains each.
  SOURCES = {
    "Landsat (NASA/USGS) · Sentinel-2 (ESA)" => "ndvi", "NASA MODIS (Terra)" => "vegetation_normal",
    "NASA POWER · FAO-56" => "water_need", "NASA POWER · NASA GPM IMERG · FAO-56" => "water_need", "NASA SMAP L4" => "soil_moisture", "NASA ECOSTRESS" => "water_stress",
    "NASA GRACE / GRACE-FO" => "water_storage", "NASA GPM IMERG" => "heavy_rain", "NASA NASADEM" => "slope",
    "USGS 3DEP" => "slope", "FAO GAEZ v4" => "suitability", "FAO ECOCROP" => "requirements"
  }.freeze

  def show
  end
end
