# frozen_string_literal: true

module Crops
  # How a crop's ECOCROP requirements (config/ecocrop.yml) sit against a
  # field: the long-term temperature and rain at its pin (NASA POWER
  # climatology) and the soil the farmer confirmed (pH, texture, drainage,
  # depth, salinity).
  # Each check is :optimal, :possible (inside the absolute range), :outside,
  # or :unknown when either side is missing. ECOCROP ranges are species-level
  # rules, not a yield forecast.
  class Fit
    Check = Struct.new(:factor, :status, :value, :range, keyword_init: true)
    # Ordered classes: the field's answer against ECOCROP's optimal and tolerated limits.
    DEPTHS = %w[shallow medium deep].freeze     # a crop needs at least its depth
    SALINITY = %w[low medium high].freeze       # a crop takes at most its salinity

    def initialize(crop, season:, soil:)
      @requirements = Agronomy.find(crop)&.requirements.to_h
      @climatology = season.climatology
      @soil = soil.to_h
    end

    def available? = @requirements.any?

    def checks
      return [] unless available?

      [ range_check("temperature", @climatology.dig("T2M", "ANN"), "topmn", "topmx", "tmin", "tmax"),
        range_check("rain", @climatology.dig("PRECTOTCORR", "ANN")&.*(365), "ropmn", "ropmx", "rmin", "rmax"),
        range_check("ph", @soil["ph"], "phopmn", "phopmx", "phmin", "phmax"),
        class_check("texture", @soil["texture"], "text", "textr"),
        class_check("drainage", @soil["drainage"], "dra", "drar"),
        ordered_check("depth", @soil["depth"], DEPTHS, "dep", "depr", at_least: true),
        ordered_check("salinity", @soil["salinity"], SALINITY, "sal", "salr", at_least: false) ]
    end

    private

    def range_check(factor, value, opt_min, opt_max, abs_min, abs_max)
      lo, hi, min, max = @requirements.values_at(opt_min, opt_max, abs_min, abs_max)
      status = if value.nil? || lo.nil? || hi.nil? then :unknown
      elsif value.between?(lo, hi) then :optimal
      elsif min && max && value.between?(min, max) then :possible
      else :outside
      end
      Check.new(factor: factor, status: status, value: value, range: [ lo, hi ].compact)
    end

    # ECOCROP lists the suitable classes as text ("heavy, medium", "poorly (saturated...)"):
    # in the optimal list is optimal, in the tolerated one possible.
    def class_check(factor, value, column, range_column)
      allowed = @requirements[column].to_s.downcase
      tolerated = @requirements[range_column].to_s.downcase
      status = if value.blank? || (allowed.blank? && tolerated.blank?) then :unknown
      elsif allowed.include?(value.to_s) || allowed.start_with?("wide") then :optimal
      elsif tolerated.include?(value.to_s) then :possible
      else :outside
      end
      Check.new(factor: factor, status: status, value: value, range: allowed.split(/[,;]\s*/))
    end

    # Depth and salinity are ordered: "medium (50-150 cm)" optimal and "shallow (20-50 cm)"
    # tolerated mean at least medium is best and shallow still works (at_least), while for
    # salinity the classes are ceilings.
    def ordered_check(factor, value, scale, column, range_column, at_least:)
      rank = ->(text) { scale.index(text.to_s.downcase[/\A[a-z]+/]) }
      field = scale.index(value.to_s)
      best = rank.call(@requirements[column])
      limit = rank.call(@requirements[range_column]) || best
      status = if field.nil? || best.nil? then :unknown
      elsif at_least ? field >= best : field <= best then :optimal
      elsif at_least ? field >= limit : field <= limit then :possible
      else :outside
      end
      Check.new(factor: factor, status: status, value: value, range: [ @requirements[column], @requirements[range_column] ].compact)
    end
  end
end
