# frozen_string_literal: true

module Cdl
  # USDA Cropland Data Layer (docs/data_sources/cropland_cdl.md): the crop
  # mapped at one 30 m pixel each year, contiguous United States. The service
  # wants CONUS Albers (EPSG:5070) metres, converted here as farm_data.py
  # does. A year's layer appears the following winter.
  class Client < DataSources::Client
    BASE_URL = "https://nassgeodata.gmu.edu/axis2/services/CDLService/"
    CATEGORY = /category:\s*"?([^",}]+)/

    # { "2025" => "Corn", "2024" => "Soybeans", ... } for the years that answered.
    def history(latitude:, longitude:, years:)
      x, y = self.class.albers(latitude.to_f, longitude.to_f)
      years.each_with_object({}) do |year, out|
        text = get("GetCDLValue", json: false, year: year, x: x.round(1), y: y.round(1))
        category = text.to_s[CATEGORY, 1]&.strip
        out[year.to_s] = category if category.present?
      rescue Error
        next # one missing year (not released yet) does not lose the others
      end
    end

    # WGS84/NAD83 to CONUS Albers Equal Area (EPSG:5070), GRS80 ellipsoid.
    def self.albers(lat, lon)
      a = 6_378_137.0
      f = 1 / 298.257222101
      e2 = f * (2 - f)
      e = Math.sqrt(e2)
      rad = ->(deg) { deg * Math::PI / 180 }
      m = ->(p) { Math.cos(p) / Math.sqrt(1 - (e2 * (Math.sin(p)**2))) }
      q = lambda do |p|
        s = Math.sin(p)
        (1 - e2) * ((s / (1 - (e2 * s * s))) - ((1 / (2 * e)) * Math.log((1 - (e * s)) / (1 + (e * s)))))
      end
      p1, p2, p0, l0 = [ 29.5, 45.5, 23.0, -96.0 ].map(&rad)
      n = ((m.(p1)**2) - (m.(p2)**2)) / (q.(p2) - q.(p1))
      c = (m.(p1)**2) + (n * q.(p1))
      rho = ->(qq) { a * Math.sqrt(c - (n * qq)) / n }
      theta = n * (rad.(lon) - l0)
      r = rho.(q.(rad.(lat)))
      [ r * Math.sin(theta), rho.(q.(p0)) - (r * Math.cos(theta)) ]
    end
  end
end
