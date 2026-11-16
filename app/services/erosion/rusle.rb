# frozen_string_literal: true

module Erosion
  # Soil lost a year under a three-season crop sequence, with and without a
  # cereal rye cover between crops: RUSLE, A = R x K x LS x C (Renard et al.
  # 1997, USDA Agriculture Handbook 703), ported from
  # docs/proposal/validation/v6_erosion.rb, which found the comparator's erosion
  # score orders the strategies the way RUSLE does at Ames.
  #
  #   R   erosivity from the annual rain normal (Renard and Freimund 1994), spread
  #       over the year by the modified Fournier index (each month's share
  #       goes with its rain squared, Arnoldus 1980) where the hindcast had daily rain
  #   K   SSURGO kwfact of the topsoil, to SI units (x 0.1317)
  #   LS  McCool et al. (1987, 1989) from the slope and the SSURGO USLE slope length
  #   C   a soil-loss ratio per day: canopy cover from the FAO-56 Kc curve and
  #       residue cover, both from AH-703 (Eq. 5-4 and b = 0.035)
  #
  # The residue left after harvest, the canopy fall height and the cover crop's
  # canopy are ASSUMPTIONS (tagged in #assumptions): the tonnes rank the
  # rotations and show what a cover saves, they are not a measured loss.
  # US only, where the soil survey gives K, slope length and the tolerable loss T.
  class Rusle
    SI_K = 0.1317                 # US customary K to t ha h / (ha MJ mm)
    T_SI = 2.2417                 # t/acre/yr to t/ha/yr
    RESIDUE = { "stalk" => 50.0, "grain" => 40.0, "leafy" => 20.0 }.freeze   # % surface cover after harvest, reduced tillage
    RESIDUE_CROP = { "helianthus-annuus" => 20.0 }.freeze                       # a stalk crop that leaves little behind
    FALL_HEIGHT = { "stalk" => 1.0, "grain" => 0.5, "leafy" => 0.4 }.freeze  # m, half the FAO-56 Table 12 heights
    CANOPY_SHAPE = { "stalk" => 2.0, "grain" => 1.0, "leafy" => 0.75 }.freeze # FAO-56 crop height for Eq. 76's exponent
    COVER_FC = 0.5                # rye canopy reached COVER_RAMP days after sowing; it grows little in winter
    COVER_RAMP = 60.0
    COVER_HEIGHT = 0.3
    YEAR = 365

    Loss = Struct.new(:no_cover, :with_cover, :saved_pct, :tolerable, keyword_init: true) do
      def over_tolerable? = tolerable.present? && no_cover > tolerable
    end

    # From a field's observations; nil without the soil survey, a slope or rain.
    def self.for(field, slope:)
      soil = field.observation("ssurgo")
      soil = soil&.ok? ? soil.payload.to_h : {}
      k, length = soil["kwfact"], soil["slopelenusle_r"]
      return nil unless k && length && slope

      months = monthly_rain(field)
      return nil unless months

      new(k: Float(k), slope_length: Float(length), slope: Float(slope), tolerable: soil["tfact"] && Float(soil["tfact"]) * T_SI, monthly_mm: months)
    end

    # Twelve mean monthly totals (mm): NASA GPM IMERG first, NASA POWER normals otherwise.
    def self.monthly_rain(field)
      imerg = Weather::RainExtremes.new(field.observation("gpm_imerg")).months
      return imerg.sort_by(&:month).map { |m| m.rain_mm.to_f } if imerg.size == 12 && imerg.sum { |m| m.rain_mm.to_f }.positive?

      power = field.observation("nasa_power")
      normals = power&.ok? ? power.payload.dig("climatology", "PRECTOTCORR").to_h : {}
      values = Weather::Season::MONTHS.each_with_index.map { |name, i| normals[name] && normals[name] * Time.days_in_month(i + 1, 2025) }
      values.all? ? values : nil
    end

    def self.assumptions = { residue: RESIDUE.merge(RESIDUE_CROP), fall_height: FALL_HEIGHT, cover_fc: COVER_FC, cover_ramp_days: COVER_RAMP }

    attr_reader :k, :slope, :slope_length, :tolerable, :monthly_mm

    def initialize(k:, slope:, slope_length:, monthly_mm:, tolerable: nil)
      @k = k * SI_K
      @slope = slope
      @slope_length = slope_length
      @monthly_mm = monthly_mm
      @tolerable = tolerable&.round(1)
    end

    # Loss for a crop sequence (one crop key per season), or nil when a crop has no FAO-56 curve.
    def loss(crops)
      return nil unless crops.all? { |c| Crops::Agronomy.find(c)&.fao56 }

      bare = annual(crops, cover: false)
      covered = annual(crops, cover: true)
      return nil unless bare.finite? && bare.positive?

      Loss.new(no_cover: bare.round(1), with_cover: covered.round(1), saved_pct: (100 * (bare - covered) / bare).round, tolerable: tolerable)
    end

    def r_factor
      p = monthly_mm.sum
      p <= 850 ? 0.0483 * (p**1.61) : 587.8 - (1.219 * p) + (0.004105 * (p**2))
    end

    def ls_factor
      theta = Math.atan(slope / 100.0)
      beta = (Math.sin(theta) / 0.0896) / ((3 * (Math.sin(theta)**0.8)) + 0.56)
      m = beta / (1 + beta)
      s = slope < 9 ? (10.8 * Math.sin(theta)) + 0.03 : (16.8 * Math.sin(theta)) - 0.50
      ((slope_length / 22.13)**m) * s
    end

    private

    def annual(crops, cover:) = r_factor * k * ls_factor * c_factor(crops, cover: cover)

    # Day-of-year erosivity weights summing to 1.
    def weights
      @weights ||= begin
        index = monthly_mm.map { |mm| mm**2 }
        total = index.sum.nonzero? || 1.0
        (1..YEAR).map do |j|
          month = Date.ordinal(2025, j).month
          index[month - 1] / total / Time.days_in_month(month, 2025)
        end
      end
    end

    def c_factor(crops, cover:)
      slr(crops, cover: cover).each_with_index.sum { |ratio, i| ratio * weights[i % YEAR] } / crops.size
    end

    # Soil-loss ratio for each day of the sequence.
    def slr(crops, cover:)
      line = Array.new(YEAR * crops.size)
      crops.each_with_index do |crop, s|
        entry = Crops::Agronomy.find(crop)
        fao = entry.fao56
        start = (s * YEAR) + Date.new(2025, fao["planting_month"], 1).yday - 1
        fao["stages"].sum.times { |i| line[start + i] = [ entry, canopy(entry, i) ] if start + i < line.size }
      end
      residue_of = Crops::Agronomy.find(crops.first)
      since_harvest = nil
      line.map do |day|
        if day
          residue_of, fc = day
          since_harvest = 0
          cc = 1 - (fc * Math.exp(-0.1 * FALL_HEIGHT.fetch(residue_of.shape, 0.4)))
          cc * Math.exp(-0.035 * residue(residue_of) * 0.5)
        else
          since_harvest = since_harvest.nil? ? 120 : since_harvest + 1
          fc = cover ? COVER_FC * [ since_harvest / COVER_RAMP, 1 ].min : 0
          (1 - (fc * Math.exp(-0.1 * COVER_HEIGHT))) * Math.exp(-0.035 * residue(residue_of))
        end
      end
    end

    def residue(entry) = RESIDUE_CROP[entry.key] || RESIDUE.fetch(entry.shape, 20.0)

    # Canopy fraction on day i of a season, FAO-56 Eq. 76 on the Kc curve.
    def canopy(entry, i)
      kc_ini, kc_mid, = entry.fao56["kc"]
      k = Crops::WaterNeed.kc_at(i, entry.fao56["kc"], entry.fao56["stages"])
      kmax = kc_mid + 0.05
      (((k - kc_ini) / (kmax - kc_ini)).clamp(0, 1))**(1 + (0.5 * CANOPY_SHAPE.fetch(entry.shape, 1.0)))
    end
  end
end
