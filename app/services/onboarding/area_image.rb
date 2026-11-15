module Onboarding
  # A NASA GIBS WMS picture of the area around a pin for "is this your area?".
  # The browser loads the URL (img-src https: is allowed); nothing is fetched
  # server side. Blue Marble is static and cloud-free; the daily true-colour
  # layer needs a TIME. WMS 1.3.0 with EPSG:4326 orders BBOX as
  # minlat,minlon,maxlat,maxlon (docs/data_sources/gibs_worldview.md).
  class AreaImage
    BASE_URL = "https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi"
    DEFAULT_LAYER = "BlueMarble_NextGeneration"
    DAILY_LAYER = "MODIS_Terra_CorrectedReflectance_TrueColor"

    def self.url(latitude:, longitude:, span: 0.5, size: 512, layer: DEFAULT_LAYER, time: nil)
      half = span.to_f / 2
      lat = latitude.to_f.clamp(-90 + half, 90 - half)
      lon = longitude.to_f.clamp(-180 + half, 180 - half)
      bbox = [ lat - half, lon - half, lat + half, lon + half ].map { |v| format("%.4f", v) }.join(",")
      params = {
        SERVICE: "WMS", VERSION: "1.3.0", REQUEST: "GetMap", LAYERS: layer, STYLES: "",
        CRS: "EPSG:4326", BBOX: bbox, WIDTH: size.to_i, HEIGHT: size.to_i, FORMAT: "image/jpeg"
      }
      params[:TIME] = time.to_date.iso8601 if time
      "#{BASE_URL}?#{params.to_query}"
    end
  end
end
