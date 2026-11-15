# frozen_string_literal: true

module Fcc
  # FCC Census Block API (docs/data_sources/fcc_census_block.md): the US state
  # and county that contain a point. Outside the US every field comes back
  # null, which is how the US data layer knows whether it applies.
  class Client < DataSources::Client
    BASE_URL = "https://geo.fcc.gov/api/census/"

    # { "state_code" => "NE", "state" => "Nebraska", "county" => "York County", "county_fips" => "31185" } or {} outside the US.
    def locate(latitude:, longitude:)
      body = get("block/find", latitude: latitude.to_f, longitude: longitude.to_f, format: "json")
      state = body.dig("State", "code")
      return {} if state.blank?

      { "state_code" => state, "state" => body.dig("State", "name"), "county" => body.dig("County", "name"),
        "county_fips" => body.dig("County", "FIPS") }
    end
  end
end
