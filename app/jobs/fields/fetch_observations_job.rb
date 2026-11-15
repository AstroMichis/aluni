# frozen_string_literal: true

module Fields
  # Asks the public data sources about a field's pin and keeps one
  # FieldObservation per source. Global first (NASA POWER, FAO GAEZ, the
  # monthly Landsat/Sentinel-2 NDVI and NASADEM slope from Planetary Computer); the US
  # layer (SSURGO, USGS 3DEP, Cropland Data Layer) only when FCC places the pin
  # in a US state. A source that fails is recorded as failed and the others
  # still run; a paused `data` switch holds the whole job (ApplicationJob).
  # Enqueued when a pin is set or moved (Field#after_commit) and from
  # "Refresh data". When Planetary Computer rate-limits the NDVI, only that
  # source runs again later (`only: "vegetation"`), up to VEGETATION_RETRIES times.
  class FetchObservationsJob < ApplicationJob
    queue_as :default

    # Crops whose GAEZ potential is worth knowing on any field, besides its own.
    GAEZ_CANDIDATES = [ "Maize", "Soybean", "Wheat", "Oat", "Barley", "Sorghum", "Phaseolus bean", "Alfalfa" ].freeze
    CDL_YEARS = 5
    US_SOURCES = %w[ssurgo usgs_elevation cdl].freeze
    VEGETATION_MONTHS = 12
    VEGETATION_RETRIES = 3
    VEGETATION_RETRY_WAIT = 15.minutes # times the attempt, plus up to 5 minutes of jitter

    def perform(field_id, only: nil, attempt: 0)
      field = Field.includes(:field_crops, farm: { user: :farmer_profile }).find_by(id: field_id)
      return unless field&.located?

      @field = field
      @point = { latitude: field.latitude.to_f, longitude: field.longitude.to_f }
      return retry_vegetation(attempt) if only == "vegetation"

      us = record("fcc") { Fcc::Client.new.locate(**@point) }&.ok?
      record("nasa_power") { power }
      record("gaez") { gaez }
      record("vegetation") { vegetation }
      record("nasadem") { nasadem }
      US_SOURCES.each do |source|
        us ? record(source) { send(source) } : mark(source, :out_of_coverage)
      end
      place_farm if us
      retry_vegetation_later(attempt) if @vegetation_rate_limited
    end

    private

    def power
      client = NasaPower::Client.new
      to = Date.current - 2 # POWER publishes a day 1 to 3 days late
      from = to.beginning_of_year
      from = from.prev_year if (to - from) < 30
      { "from" => from.iso8601, "to" => to.iso8601, "daily" => client.daily(**@point, from: from, to: to),
        "climatology" => client.climatology(**@point), "elevation" => client.elevation }.compact
    end

    def gaez
      client = Gaez::Client.new
      own = @field.field_crops.filter_map { |crop| Crops::Agronomy.gaez_name(crop) }
      input = high_input? ? "High" : "Low"
      layers = client.layers(crops: (own + GAEZ_CANDIDATES).uniq, input_level: input)
      crops = layers.to_h do |crop, ids|
        [ crop, { "suitability" => ids["suitability"] && client.value(**@point, objectid: ids["suitability"]),
                  "yield" => ids["yield"] && client.value(**@point, objectid: ids["yield"]), "yield_units" => ids["yield_units"] }.compact ]
      end
      crops.values.all?(&:empty?) ? {} : { "input_level" => input, "water_supply" => "Rainfed", "crops" => crops }
    end

    # One clear-sky NDVI per month over the last year at the pin (Fields::Vegetation reads it).
    def vegetation
      client = PlanetaryComputer::Client.new
      months = client.monthly_ndvi(lat: @point[:latitude], lon: @point[:longitude], months: VEGETATION_MONTHS)
      if months.nil?
        @vegetation_rate_limited = client.rate_limited?
        raise DataSources::Client::Error, "Planetary Computer: #{client.last_error&.dig(:message)}"
      end

      months.any? { |m| m["ndvi"] } ? { "months" => months, "source" => Fields::Vegetation::SOURCE } : {}
    end

    def retry_vegetation(attempt)
      record("vegetation") { vegetation }
      retry_vegetation_later(attempt) if @vegetation_rate_limited
    end

    # Planetary Computer's burst limit clears in minutes; ask again, spread out.
    def retry_vegetation_later(attempt)
      return if attempt >= VEGETATION_RETRIES

      wait = (VEGETATION_RETRY_WAIT * (attempt + 1)) + rand(0..300).seconds
      self.class.set(wait: wait).perform_later(@field.id, only: "vegetation", attempt: attempt + 1)
    end

    # Global elevation and slope (NASADEM); 3DEP stays first in the US, this fills the rest.
    def nasadem
      client = PlanetaryComputer::Client.new
      terrain = client.terrain(lat: @point[:latitude], lon: @point[:longitude])
      raise DataSources::Client::Error, "NASADEM: #{client.last_error&.dig(:message)}" if terrain.nil?

      terrain
    end

    def ssurgo = Ssurgo::Client.new.soil(**@point)
    def usgs_elevation = Usgs::ElevationClient.new.terrain(**@point)

    def cdl
      last = Date.current.year - 1
      years = Cdl::Client.new.history(**@point, years: (last - CDL_YEARS + 1..last).to_a.reverse)
      years.any? ? { "years" => years } : {}
    end

    # GAEZ's high-input layers fit a farm with money and machinery; the rest read low input.
    def high_input?
      profile = @field.farm.user.farmer_profile
      return false unless profile

      profile.budget_level_high? || profile.segment_mid_mechanized? || profile.segment_large_commercial?
    end

    def record(source)
      payload = yield
      save(source, payload.present? ? :ok : :empty, payload.presence || {})
    rescue DataSources::Client::Error => e
      Rails.logger.warn("[#{self.class.name}] #{source} failed for field #{@field.id}: #{e.message}")
      save(source, :failed, {}, e.message)
    end

    def mark(source, status) = save(source, status, {})

    def save(source, status, payload, error = nil)
      observation = @field.observations.find_or_initialize_by(source: source)
      observation.update!(status: status, payload: payload, error: error, fetched_at: Time.current)
      observation
    end

    # The country and region come from the pin, never asked (Farm).
    def place_farm
      fcc = @field.observations.find_by(source: "fcc")&.payload.to_h
      farm = @field.farm
      return if farm.country_code.present? || fcc["state"].blank?

      farm.update!(country_code: "US", admin_area: fcc["state"])
    end
  end
end
