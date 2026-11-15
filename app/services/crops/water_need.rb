# frozen_string_literal: true

module Crops
  # How much water a crop needs over its season at a pin, and how much the
  # usual rain covers: crop evapotranspiration (FAO-56 single Kc curve on the
  # monthly reference ET0 from NASA POWER) against effective rain (FAO/CROPWAT
  # formula). Only crops whose FAO-56 values were captured have a need
  # (config/crops.yml `fao56`).
  #
  # The rain is NASA GPM IMERG's 20-year monthly mean when the field has it,
  # else the POWER normal: against 59 rain gauges near Ames, Iowa, POWER read
  # about 12 % low in every season of 2008-2025 while IMERG passed the same
  # test (docs/proposal/validation, study V1).
  #
  # The season starts in the farmer's own planting month, else the regional
  # calendar (Crops::PlantingCalendar), else the FAO-56 row for the hemisphere.
  #
  # Typical-year figures for comparing crops and flagging drought risk. The
  # same hindcast found they rank the drought years but do not predict yield
  # (study V2), so no screen turns them into a harvest figure.
  class WaterNeed
    Need = Struct.new(:crop_mm, :rain_mm, :effective_mm, :deficit_mm, :days, :planting_month, :rain_source, keyword_init: true)

    # FAO-56 Table 11 planting months are northern rows. South of this latitude the
    # seasons are reversed, so the default month moves by six; nearer the equator
    # planting follows the rains, not the calendar, and the row is kept.
    SOUTHERN_SEASONS_FROM = -15.0

    # observation: the "nasa_power" one (already shifted when a scenario applies);
    # imerg: the "gpm_imerg" one, whose rain takes the scenario's rain change here;
    # place: { country_code:, admin_area: } for the regional planting calendar.
    def self.for(crop, observation:, latitude:, planting_month: nil, imerg: nil, scenario: nil, place: {})
      fao = Agronomy.find(crop)&.fao56
      payload = observation&.ok? ? observation.payload.to_h : {}
      climatology = payload["climatology"].to_h
      return nil unless fao && climatology.any?

      et0 = Weather::Et0.monthly(climatology, latitude: latitude, elevation: payload["elevation"].to_i)
      return nil unless et0

      rain, source = rain_normals(climatology, imerg, scenario)
      month = planting_month || PlantingCalendar.month(crop, **place) || default_month(fao["planting_month"], latitude)
      new(fao, et0, rain, month, rain_source: source).need
    end

    # [{ "JAN" => mm/day, ... }, "imerg" | "power"]: IMERG's monthly means scaled by
    # the scenario's rain change (the POWER normal arrives already shifted), or POWER.
    def self.rain_normals(climatology, imerg, scenario = nil)
      months = Weather::RainExtremes.new(imerg).months
      if months.size == 12 && months.all?(&:rain_mm)
        factor = 1 + (scenario&.rain || 0)
        rain = months.to_h { |m| [ Weather::Season::MONTHS[m.month - 1], m.rain_mm.to_f * factor / Time.days_in_month(m.month, 2001) ] }
        return [ rain, "imerg" ]
      end

      [ climatology["PRECTOTCORR"].to_h, "power" ]
    end

    # The FAO row's month, six months later south of SOUTHERN_SEASONS_FROM.
    def self.default_month(month, latitude)
      return month unless latitude && latitude.to_f < SOUTHERN_SEASONS_FROM

      ((month.to_i + 5) % 12) + 1
    end

    def initialize(fao, et0, rain, planting_month, rain_source: "power")
      @kc_ini, @kc_mid, @kc_end = fao["kc"]
      @stages = fao["stages"]
      @et0 = et0
      @rain = rain
      @planting_month = planting_month.to_i
      @rain_source = rain_source
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
               deficit_mm: crop.sum { |month, mm| [ mm - effective[month], 0 ].max }.round, days: @stages.sum,
               planting_month: @planting_month, rain_source: @rain_source)
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
