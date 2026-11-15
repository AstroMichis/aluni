# frozen_string_literal: true

module Weather
  # FAO-56 Penman-Monteith reference evapotranspiration (mm/day) for each
  # month of a typical year, from NASA POWER's monthly normals at a pin:
  # T2M, RH2M, WS2M (wind at 2 m) and ALLSKY_SFC_SW_DWN (MJ/m2/day, AG
  # community). Monthly means give mean temperature only, so vapour pressure
  # uses it (FAO-56 notes this underestimates slightly); soil heat flux is
  # taken as zero over a month. Returns nil when a normal is missing.
  module Et0
    SIGMA = 4.903e-9 # Stefan-Boltzmann, MJ K-4 m-2 day-1
    GSC = 0.0820     # solar constant, MJ m-2 min-1
    ALBEDO = 0.23
    MONTHS = Season::MONTHS

    module_function

    def monthly(climatology, latitude:, elevation:)
      pressure = 101.3 * (((293 - (0.0065 * elevation.to_f)) / 293)**5.26)
      gamma = 0.000665 * pressure
      MONTHS.each_with_index.to_h do |name, i|
        t, rh, u2, rs = %w[T2M RH2M WS2M ALLSKY_SFC_SW_DWN].map { |p| climatology.dig(p, name) }
        return nil if [ t, rh, u2, rs ].any?(&:nil?)

        es = 0.6108 * Math.exp(17.27 * t / (t + 237.3))
        ea = es * rh / 100.0
        delta = 4098 * es / ((t + 237.3)**2)
        ra = extraterrestrial(latitude.to_f, Date.new(2001, i + 1, 15).yday)
        rso = (0.75 + (2e-5 * elevation.to_f)) * ra
        rnl = SIGMA * ((t + 273.16)**4) * (0.34 - (0.14 * Math.sqrt(ea))) * ((1.35 * [ rs / rso, 1.0 ].min) - 0.35)
        rn = ((1 - ALBEDO) * rs) - rnl
        et0 = ((0.408 * delta * rn) + (gamma * (900 / (t + 273)) * u2 * (es - ea))) / (delta + (gamma * (1 + (0.34 * u2))))
        [ i + 1, [ et0, 0 ].max.round(2) ]
      end
    end

    # Extraterrestrial radiation Ra (MJ/m2/day) for a latitude and day of the year (FAO-56 Eq. 21).
    def extraterrestrial(latitude, day)
      phi = latitude * Math::PI / 180
      dr = 1 + (0.033 * Math.cos(2 * Math::PI * day / 365))
      decl = 0.409 * Math.sin((2 * Math::PI * day / 365) - 1.39)
      ws = Math.acos((-Math.tan(phi) * Math.tan(decl)).clamp(-1, 1))
      (24 * 60 / Math::PI) * GSC * dr * ((ws * Math.sin(phi) * Math.sin(decl)) + (Math.cos(phi) * Math.cos(decl) * Math.sin(ws)))
    end
  end
end
