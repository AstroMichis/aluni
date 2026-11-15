# frozen_string_literal: true

module Crops
  # How a crop's ECOCROP requirements (config/ecocrop.yml) sit against a
  # field: the long-term temperature and rain at its pin (NASA POWER
  # climatology) and the soil the farmer confirmed (pH, texture, drainage).
  # Each check is :optimal, :possible (inside the absolute range), :outside,
  # or :unknown when either side is missing. ECOCROP ranges are species-level
  # rules, not a yield forecast.
  class Fit
    Check = Struct.new(:factor, :status, :value, :range, keyword_init: true)

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
        class_check("texture", @soil["texture"], "text"),
        class_check("drainage", @soil["drainage"], "dra") ]
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

    # ECOCROP lists the suitable classes as text ("heavy, medium"); a match is optimal.
    def class_check(factor, value, column)
      allowed = @requirements[column].to_s.downcase
      status = if value.blank? || allowed.blank? then :unknown
      elsif allowed.include?(value.to_s) then :optimal
      else :outside
      end
      Check.new(factor: factor, status: status, value: value, range: allowed.split(/[,;]\s*/))
    end
  end
end
