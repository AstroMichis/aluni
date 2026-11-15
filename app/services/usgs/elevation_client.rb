# frozen_string_literal: true

module Usgs
  # USGS 3DEP elevation (EPQS, docs/data_sources/terrain.md), United States
  # only, mostly lidar. Slope comes from four neighbours 30 m away, the same
  # way farm_data.py derives it. EPQS sometimes answers 200 with no value; it
  # is asked again a couple of times.
  class ElevationClient < DataSources::Client
    BASE_URL = "https://epqs.nationalmap.gov/v1/"
    STEP_M = 30.0
    TRIES = 3

    # { "elevation" => 321.7, "slope" => 4.05 } (metres, percent)
    def terrain(latitude:, longitude:)
      lat = latitude.to_f
      lon = longitude.to_f
      dlat = STEP_M / 111_320
      dlon = STEP_M / (111_320 * Math.cos(lat * Math::PI / 180))
      dzdx = (elevation(lat, lon + dlon) - elevation(lat, lon - dlon)) / (2 * STEP_M)
      dzdy = (elevation(lat + dlat, lon) - elevation(lat - dlat, lon)) / (2 * STEP_M)
      { "elevation" => elevation(lat, lon).round(1), "slope" => (100 * Math.hypot(dzdx, dzdy)).round(2) }
    end

    private

    def elevation(lat, lon)
      TRIES.times do
        value = Float(get("json", x: lon, y: lat, units: "Meters", wkid: 4326).to_h["value"], exception: false)
        return value if value && value > -1000
      end
      raise Error, "#{self.class.name}: no elevation at #{lat},#{lon}"
    end
  end
end
