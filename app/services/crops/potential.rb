# frozen_string_literal: true

module Crops
  # What FAO GAEZ v4 says about crops at a field's pin (FieldObservation
  # "gaez"): the suitability index (0-10000) in GAEZ's classes and the
  # attainable yield of the best suitability class, in t/ha. Rainfed layers,
  # 1981-2010 climate, at the input level that matches the farmer.
  class Potential
    # GAEZ suitability classes by index (SI x 100): very high > 85, ... not suitable 0.
    CLASSES = [ [ 8500, "very_high" ], [ 7000, "high" ], [ 5500, "good" ], [ 4000, "medium" ],
                [ 2500, "moderate" ], [ 1000, "marginal" ], [ 1, "very_marginal" ], [ 0, "not_suitable" ] ].freeze

    Row = Struct.new(:gaez, :entry, :suitability, :suitability_class, :yield_t, keyword_init: true)

    def initialize(observation)
      @payload = observation&.ok? ? observation.payload.to_h : {}
    end

    def available? = rows.any?
    def input_level = @payload["input_level"]

    def rows
      @rows ||= @payload["crops"].to_h.map do |name, values|
        index = values["suitability"]
        Row.new(gaez: name, entry: Agronomy.entries.values.find { |e| e.gaez == name }, suitability: index,
                suitability_class: index && CLASSES.find { |limit, _| index >= limit }&.last,
                yield_t: tonnes(values["yield"], values["yield_units"]))
      end
    end

    # The row for a FieldCrop or crop name, through the catalog's GAEZ name.
    def for(crop)
      name = Agronomy.gaez_name(crop)
      rows.find { |row| row.gaez == name }
    end

    def ranked = rows.select(&:suitability).sort_by { |row| -row.suitability }

    private

    # GAEZ yields come in "kg DW/ha" or "10kg DW/ha" (alfalfa); dry weight.
    def tonnes(value, units)
      return nil unless value.is_a?(Numeric)

      factor = units.to_s.start_with?("10kg") ? 10 : 1
      (value * factor / 1000.0).round(1)
    end
  end
end
