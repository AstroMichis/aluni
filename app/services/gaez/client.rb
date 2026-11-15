# frozen_string_literal: true

module Gaez
  # FAO GAEZ v4 ImageServer (docs/data_sources/gaez.md): crop suitability and
  # attainable yield for the 1981-2010 climate, global, ~9 km. The catalog
  # query finds each crop's layers; identify reads one layer at a point. Only
  # rainfed layers are queried (irrigated queries returned nothing in the
  # docs); the input level follows the farmer's budget.
  class Client < DataSources::Client
    BASE_URL = "https://gaez-services.fao.org/server/rest/services/res05/ImageServer/"
    # yx: attainable yield of the best suitability class; sx: suitability index 0-10000.
    LAYER = /\A(yx|sx)[HL]r_/

    # { "Maize" => { "yield" => objectid, "yield_units" => "kg DW/ha", "suitability" => objectid }, ... }
    def layers(crops:, input_level:)
      list = crops.map { |crop| "'#{crop.delete("'")}'" }.join(",")
      where = "year='1981-2010' AND model='CRUTS32' AND water_supply='Rainfed' AND input_level='#{input_level}' " \
              "AND c02_fertilization='With CO2 Fertilization' AND crop IN (#{list})"
      body = get("query", where: where, outFields: "objectid,name,crop,units", returnGeometry: false, f: "json")
      Array(body["features"]).each_with_object({}) do |feature, out|
        a = feature["attributes"].to_h
        kind = a["name"].to_s[LAYER, 1] or next
        entry = out[a["crop"].to_s.strip] ||= {}
        entry[kind == "yx" ? "yield" : "suitability"] = a["objectid"]
        entry["yield_units"] = a["units"].to_s.strip if kind == "yx"
      end
    end

    # The layer's value at the point, or nil (NoData, water, outside the crop's range).
    def value(latitude:, longitude:, objectid:)
      body = get("identify", geometry: { x: longitude.to_f, y: latitude.to_f }.to_json, geometryType: "esriGeometryPoint",
                             mosaicRule: { mosaicMethod: "esriMosaicLockRaster", lockRasterIds: [ objectid ] }.to_json,
                             returnCatalogItems: false, f: "json")
      Float(body["value"], exception: false)
    end
  end
end
