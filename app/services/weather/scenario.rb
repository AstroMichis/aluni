# frozen_string_literal: true

module Weather
  # A "what if" on a field's long-term climate, for the rotation plan: NASA
  # POWER's monthly normals shifted by a warming (°C, added to the mean, the
  # highs and the lows) and a change in rain (a share, -0.2 is 20 % less).
  # Everything downstream recomputes from the shifted normals: the FAO-56
  # reference evapotranspiration and so each crop's water need, and the
  # timeline's frost, heat and dry months. A sketch for comparing strategies
  # under a plausible change, not a climate projection.
  class Scenario
    PRESETS = {
      "today" => { warming: 0.0, rain: 0.0 },
      "warm1" => { warming: 1.0, rain: 0.0 },
      "warm2" => { warming: 2.0, rain: 0.0 },
      "warm2_dry" => { warming: 2.0, rain: -0.2 }
    }.freeze
    TEMPERATURES = %w[T2M T2M_MAX T2M_MIN].freeze
    # Frost days fall as the lows warm: about this share fewer per °C (a rule of thumb, never below zero).
    FROST_PER_DEGREE = 0.25

    # A FieldObservation look-alike: what the comparator and the timeline read.
    Observation = Struct.new(:payload, :status, :source, keyword_init: true) do
      def ok? = status.to_s == "ok"
    end

    attr_reader :key, :warming, :rain

    def self.find(key) = new(PRESETS.key?(key.to_s) ? key.to_s : "today")

    def initialize(key)
      @key = key
      @warming = PRESETS.fetch(key)[:warming]
      @rain = PRESETS.fetch(key)[:rain]
    end

    def today? = key == "today"

    # The "nasa_power" observation with its climatology shifted, or the same one today.
    def apply(observation)
      return observation if today? || !observation&.ok?

      payload = observation.payload.to_h
      Observation.new(payload: payload.merge("climatology" => shift(payload["climatology"].to_h)), status: "ok", source: observation.source)
    end

    private

    def shift(climatology)
      climatology.to_h do |parameter, months|
        values = months.to_h
        shifted = if TEMPERATURES.include?(parameter) then values.transform_values { |v| v && (v + warming).round(2) }
        elsif parameter == "PRECTOTCORR" then values.transform_values { |v| v && (v * (1 + rain)).round(3) }
        elsif parameter == "FROST_DAYS" then values.transform_values { |v| v && [ v * (1 - (FROST_PER_DEGREE * warming)), 0 ].max.round(1) }
        else values
        end
        [ parameter, shifted ]
      end
    end
  end
end
