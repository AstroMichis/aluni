# frozen_string_literal: true

module NasaPower
  # NASA POWER point API (docs/data_sources/nasa_power.md): daily values of
  # the season so far and the long-term monthly normals, global, ~50 km cells,
  # no account. community=AG gives agroclimatology units. -999 is "no value".
  class Client < DataSources::Client
    BASE_URL = "https://power.larc.nasa.gov/api/temporal/"
    DAILY = %w[T2M T2M_MIN T2M_MAX PRECTOTCORR GWETROOT].freeze
    # RH2M, WS2M and ALLSKY_SFC_SW_DWN feed the FAO-56 reference
    # evapotranspiration (Weather::Et0).
    CLIMATOLOGY = %w[T2M T2M_MIN T2M_MAX PRECTOTCORR FROST_DAYS RH2M WS2M ALLSKY_SFC_SW_DWN].freeze
    FILL = -999

    # The grid cell's mean elevation (m) from the last answer (geometry.coordinates[2]).
    attr_reader :elevation

    # { "T2M" => { "20260101" => -4.1, ... }, ... }
    def daily(latitude:, longitude:, from:, to:)
      body = remember_elevation get("daily/point", **point(latitude, longitude), parameters: DAILY.join(","),
                                start: from.strftime("%Y%m%d"), end: to.strftime("%Y%m%d"))
      clean(body.dig("properties", "parameter"))
    end

    # { "T2M" => { "JAN" => -3.95, ..., "ANN" => 10.86 }, "FROST_DAYS" => {...}, ... }
    def climatology(latitude:, longitude:)
      clean(remember_elevation(get("climatology/point", **point(latitude, longitude), parameters: CLIMATOLOGY.join(","))).dig("properties", "parameter"))
    end

    private

    def point(latitude, longitude)
      { community: "AG", latitude: latitude.to_f.round(4), longitude: longitude.to_f.round(4), format: "JSON" }
    end

    def remember_elevation(body)
      @elevation = body.dig("geometry", "coordinates", 2) || @elevation
      body
    end

    def clean(parameters)
      parameters.to_h.transform_values { |series| series.to_h.transform_values { |v| v.to_f <= FILL ? nil : v } }
    end
  end
end
