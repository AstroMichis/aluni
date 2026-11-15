# frozen_string_literal: true

module Crops
  # How much water a crop needs over its season at a pin, and how much the
  # usual rain covers: crop evapotranspiration (FAO-56 single Kc curve on the
  # monthly reference ET0) against effective rain (FAO/CROPWAT formula on the
  # NASA POWER rain normals). Only crops whose FAO-56 values were captured
  # have a need (config/crops.yml `fao56`). Typical-year figures, not a
  # forecast.
  class WaterNeed
    Need = Struct.new(:crop_mm, :rain_mm, :effective_mm, :deficit_mm, :days, :planting_month, keyword_init: true)

    # FAO-56 Table 11 planting months are northern rows. South of this latitude the
    # seasons are reversed, so the default month moves by six; nearer the equator
    # planting follows the rains, not the calendar, and the row is kept.
    SOUTHERN_SEASONS_FROM = -15.0

    def self.for(crop, observation:, latitude:, planting_month: nil)
      fao = Agronomy.find(crop)&.fao56
      payload = observation&.ok? ? observation.payload.to_h : {}
      climatology = payload["climatology"].to_h
      return nil unless fao && climatology.any?

      et0 = Weather::Et0.monthly(climatology, latitude: latitude, elevation: payload["elevation"].to_i)
      et0 && new(fao, et0, climatology["PRECTOTCORR"].to_h, planting_month || default_month(fao["planting_month"], latitude)).need
    end

    # The FAO row's month, six months later south of SOUTHERN_SEASONS_FROM.
    def self.default_month(month, latitude)
      return month unless latitude && latitude.to_f < SOUTHERN_SEASONS_FROM

      ((month.to_i + 5) % 12) + 1
    end

    def initialize(fao, et0, rain, planting_month)
      @kc_ini, @kc_mid, @kc_end = fao["kc"]
      @stages = fao["stages"]
      @et0 = et0
      @rain = rain
      @planting_month = planting_month.to_i
    end

    def need
      crop = Hash.new(0.0)
      season = Hash.new(0)
      start = Date.new(2001, @planting_month, 1)
      @stages.sum.times do |day|
        month = (start + day).month
        crop[month] += kc(day) * @et0.fetch(month)
        season[month] += 1
      end
      rain = season.to_h { |month, days| [ month, @rain.fetch(Weather::Season::MONTHS[month - 1], 0).to_f * days ] }
      effective = rain.to_h { |month, mm| [ month, effective_rain(mm * Time.days_in_month(month, 2001) / season[month]) * season[month] / Time.days_in_month(month, 2001) ] }
      Need.new(crop_mm: crop.values.sum.round, rain_mm: rain.values.sum.round, effective_mm: effective.values.sum.round,
               deficit_mm: crop.sum { |month, mm| [ mm - effective[month], 0 ].max }.round, days: @stages.sum, planting_month: @planting_month)
    end

    private

    # Kc along the season: flat, rising, flat, falling (FAO-56 Fig. 25).
    def kc(day)
      ini, dev, mid, late = @stages
      return @kc_ini if day < ini
      return @kc_ini + ((@kc_mid - @kc_ini) * (day - ini) / dev.to_f) if day < ini + dev
      return @kc_mid if day < ini + dev + mid

      @kc_mid + ((@kc_end - @kc_mid) * (day - ini - dev - mid) / late.to_f)
    end

    # Effective monthly rain (mm) from the month's total (FAO/CROPWAT, Smith 1992).
    def effective_rain(month_mm)
      month_mm > 75 ? (0.8 * month_mm) - 25 : [ (0.6 * month_mm) - 10, 0 ].max
    end
  end
end
