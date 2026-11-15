# frozen_string_literal: true

module Rotations
  # Compares the field's current rotation with alternatives over the next
  # three seasons, with the field's own data: FAO GAEZ suitability at the pin,
  # the crop water need against the usual rain (Crops::WaterNeed), the slope
  # and how often it pours (Weather::RainExtremes, GPM IMERG),
  # the crop families of the history (Crops::RotationCheck) and the farmer's
  # goals, which weigh the criteria. Every strategy carries why it is offered,
  # the evidence and its source, its benefits against the current rotation,
  # what is not known and what to check locally. Deterministic and traceable;
  # Rotations::NarrateService only puts the "why" into words. It supports the
  # farmer's judgment, it does not replace it.
  class Comparator
    HORIZON = 3
    CRITERIA = %w[crop_fit pest_break soil_health nitrogen water erosion workload].freeze
    GOAL_WEIGHTS = { "crop_fit" => %w[crop_fit yield], "pest_break" => %w[rotation], "soil_health" => %w[soil_health],
                     "nitrogen" => %w[soil_health], "water" => %w[water_saving], "erosion" => %w[soil_health], "workload" => %w[labour] }.freeze
    GOAL_WEIGHT = 3
    LEGUMES = [ "Soybean", "Phaseolus bean", "Chickpea", "Dry pea", "Groundnut", "Cowpea" ].freeze
    SMALL_GRAINS = %w[Wheat Oat Barley Rye].freeze
    FALLBACK_OTHERS = %w[Maize Sorghum Sunflower].freeze # before GAEZ answers
    ROW_CROPS = %w[zea-mays sorghum-bicolor glycine-max phaseolus-vulgaris solanum-tuberosum helianthus-annuus gossypium-hirsutum].freeze
    STEEP = 5.0         # % slope from which a row crop leaves soil at risk
    # Where the slope comes from, sharpest first: US lidar, then NASA's global DEM.
    SLOPE_SOURCES = { "usgs_elevation" => "USGS 3DEP", "nasadem" => "NASA NASADEM" }.freeze
    STORM_PENALTY = 7   # more per row-crop season where 50 mm days come every year (GPM IMERG)
    DRY_SOIL_MONTHS = 3 # months of the last year in the driest fifth of the usual soil moisture (SMAP)
    SOIL_FACTORS = %w[texture drainage depth salinity].freeze
    SOIL_OUTSIDE = 20   # crop-fit points a soil property outside a crop's tolerance takes off
    SOIL_POSSIBLE = 5   # and one it only tolerates
    STORED_WATER = %w[well river_canal reservoir mixed].freeze # irrigation that draws on the region's store
    SUPPLY_RISK = 15    # water-score points when that store is depleted (GRACE)
    DRY_SHARE = 0.5     # a rainfed crop whose season rain is under half its need
    PERENNIALS = %w[medicago-sativa].freeze # a stand of several seasons is one crop, not a repeat
    LOW_SUITABILITY = 4000
    # Practices that already put soil health first count as that goal.
    SOIL_PRACTICES = %w[no_till regenerative organic certified_organic].freeze
    # Sales tied to a buyer: changing the crop needs the buyer's agreement.
    BOUND_CHANNELS = %w[contract export].freeze

    Strategy = Struct.new(:key, :crops, :scores, :total, :why, :benefits, :evidence, :gaps, :risks, keyword_init: true) do
      def current? = key == "current"
    end
    Fact = Struct.new(:key, :values, :source, keyword_init: true)

    attr_reader :scenario

    # scenario: a Weather::Scenario ("what if" +2 °C, less rain) that shifts the climate the scores read.
    def initialize(field, profile:, scenario: Weather::Scenario.find("today"))
      @field = field
      @record = field.record
      @profile = profile
      @potential = Crops::Potential.new(field.observation("gaez"))
      @scenario = scenario
      @power = scenario.apply(field.observation("nasa_power"))
      @goals = Array(profile&.goals)
      @goals |= [ "soil_health" ] if (Array(profile&.practices) & SOIL_PRACTICES).any?
    end

    def strategies
      @strategies ||= begin
        current, others = candidates.map { |key, crops| build(key, crops) }.partition(&:current?)
        others.each { |s| s.benefits = benefits(s, current.first) }
        current + others.sort_by { |s| -s.total.to_f }
      end
    end

    def best = strategies.reject(&:current?).max_by { |s| s.total.to_f }
    def weights = CRITERIA.to_h { |c| [ c, (GOAL_WEIGHTS[c] & @goals).any? ? GOAL_WEIGHT : 1 ] }
    def ready? = @field.current_crop.present?

    private

    # Catalog keys for the next seasons, per strategy: the current pattern and
    # at least two alternatives (a legume, a small grain, another family, and
    # perennial forage when the farm has animals or wants soil health).
    def candidates
      now = key_of(@field.current_crop)
      return {} unless now

      before = key_of(@field.history.values[-2])
      current = continue(now, before)
      families = current.filter_map { |c| Crops::Agronomy.family(c) }.uniq
      has_legume = current.any? { |c| Crops::Agronomy.legume?(c) }
      legume = best_of(LEGUMES)
      grain = best_of(SMALL_GRAINS)
      other = best_of(@potential.ranked.map(&:gaez) + FALLBACK_OTHERS, exclude: families)
      list = { "current" => current }
      list["legume"] = [ legume, now, legume ] if legume && !has_legume
      list["small_grain"] = [ grain, (has_legume ? current.find { |c| Crops::Agronomy.legume?(c) } : legume) || now, now ] if grain
      list["other_family"] = [ other, now, other ] if other
      forage = @goals.include?("soil_health") || Array(@profile&.livestock).any?
      list["perennial"] = [ "medicago-sativa", "medicago-sativa", now ] if forage && suitable?("Alfalfa") && now != "medicago-sativa"
      list.uniq { |_, crops| crops }.to_h
    end

    # The pattern the field follows: alternating two crops, or the same one again.
    def continue(now, before)
      return [ now ] * HORIZON if before.nil? || before == now

      [ before, now, before ]
    end

    def build(key, crops)
      facts = []
      gaps = []
      scores = {
        "crop_fit" => crop_fit(crops, facts, gaps), "pest_break" => pest_break(crops, facts),
        "soil_health" => soil_health(crops), "nitrogen" => nitrogen(crops), "water" => water(crops, facts, gaps),
        "erosion" => erosion(crops, facts, gaps), "workload" => workload(crops)
      }
      cover_history_fact(facts)
      double_crop_fact(crops, facts, gaps)
      vegetation_fact(facts)
      gaps << "market"
      gaps << "soil" if @record.soil["texture"].blank?
      gaps << "ecocrop" unless crops.all? { |c| Crops::Agronomy.find(c)&.requirements.present? }
      Strategy.new(key: key, crops: crops, scores: scores, total: total(scores), why: why(key, crops, scores),
                   evidence: facts.uniq { |f| [ f.key, f.values ] }, gaps: gaps.uniq, risks: risks(crops, scores), benefits: [])
    end

    def total(scores)
      present = scores.compact
      return nil if present.empty?

      w = weights
      (present.sum { |c, v| v * w[c] } / present.keys.sum { |c| w[c] }.to_f).round
    end

    # GAEZ suitability (0-10000) averaged over the seasons' crops, less what the
    # field's own soil takes off (ECOCROP: texture, drainage, depth, salinity).
    def crop_fit(crops, facts, gaps)
      values = crops.filter_map do |crop|
        row = @potential.for(crop)
        facts << Fact.new(key: "suitability", values: { crop: crop, class: row.suitability_class }, source: "FAO GAEZ v4") if row&.suitability_class
        row&.suitability
      end
      gaps << "suitability" if values.size < crops.size
      return nil if values.empty?

      ((values.sum / values.size / 100.0) - soil_penalty(crops, facts)).clamp(0, 100).round
    end

    # Per crop, the soil checks outside what it tolerates (SOIL_OUTSIDE each) or only
    # tolerated (SOIL_POSSIBLE each), averaged over the seasons; each "outside" is cited.
    def soil_penalty(crops, facts)
      penalties = crops.map do |crop|
        soil_checks(crop).sum do |check|
          next 0 unless %i[outside possible].include?(check.status)

          if check.status == :outside
            facts << Fact.new(key: "soil_#{check.factor}", values: { crop: crop, value: check.value, need: check.range.first.to_s }, source: "FAO ECOCROP")
          end
          check.status == :outside ? SOIL_OUTSIDE : SOIL_POSSIBLE
        end
      end
      penalties.sum / penalties.size.to_f
    end

    def soil_checks(crop)
      @soil_checks ||= {}
      @soil_checks[crop] ||= Crops::Fit.new(crop, season: season, soil: @record.soil).checks.select { |c| SOIL_FACTORS.include?(c.factor) }
    end

    def season = (@season ||= Weather::Season.for(@power))

    def pest_break(crops, facts)
      planned = crops.each_with_index.map { |c, i| [ "+#{i + 1}", c ] }
      planned = planned.chunk_while { |(_, a), (_, b)| a == b && PERENNIALS.include?(a) }.map(&:first)
      seasons = @field.history.to_a.last(2) + planned
      findings = Crops::RotationCheck.new(seasons).findings
      findings.each { |f| facts << Fact.new(key: f.kind, values: { crop: f.crop.respond_to?(:crop_name) ? f.crop.crop_name : f.crop }, source: nil) }
      [ 100 - (findings.count { |f| f.kind == "same_family" } * 25) - (findings.count { |f| f.kind == "monoculture" } * 30), 0 ].max
    end

    # Legumes, more families and close-growing crops build soil.
    def soil_health(crops)
      entries = crops.map { |c| Crops::Agronomy.find(c) }
      legumes = entries.count { |e| e&.legume? }
      families = entries.filter_map(&:family).uniq.size
      cover = crops.count { |c| !ROW_CROPS.include?(c) }
      [ 25 + (legumes * 20) + (families * 10) + (cover * 10), 100 ].min
    end

    def nitrogen(crops) = (100 * crops.count { |c| Crops::Agronomy.legume?(c) } / crops.size.to_f).round

    # How much of the crops' water need the usual rain covers (irrigation fills the rest).
    def water(crops, facts, gaps)
      soil_moisture_fact(facts)
      water_stress_fact(facts)
      water_storage_fact(facts)
      needs = crops.uniq.filter_map do |crop|
        need = water_need(crop) or next
        facts << Fact.new(key: "water", values: { crop: crop, need: need.crop_mm, effective: need.effective_mm }, source: "NASA POWER · FAO-56")
        [ crop, need ]
      end.to_h
      if needs.size < crops.uniq.size
        gaps << "water"
        return nil if needs.empty?
      end
      covered = crops.filter_map { |c| needs[c] }.map { |n| n.effective_mm / n.crop_mm.to_f }
      share = covered.sum / covered.size
      score = @record.uses_irrigation? ? 60 + (40 * share) - irrigation_risk(facts, gaps) : 100 * share
      score.clamp(0, 100).round
    end

    # Irrigation drawn from wells, canals or reservoirs is less sure where the region's
    # water store is depleted (GRACE); irrigation from an unknown source is a gap.
    def irrigation_risk(facts, gaps)
      if @record.water_source_unknown?
        gaps << "water_source"
        return 0
      end
      return 0 unless STORED_WATER.include?(@record.water_source) && storage.depleted?

      facts << Fact.new(key: "irrigation_supply", values: { source: @record.water_source }, source: Weather::WaterStorage::SOURCE)
      SUPPLY_RISK
    end

    def erosion(crops, facts, gaps)
      slope, source = SLOPE_SOURCES.lazy.filter_map do |obs, name|
        observation = @field.observation(obs)
        value = observation&.ok? ? observation.payload["slope"] : nil
        [ value, name ] if value
      end.first
      rain_fact(facts)
      unless slope
        gaps << "slope"
        return nil
      end

      facts << Fact.new(key: "slope", values: { value: slope }, source: source)
      rows = crops.count { |c| ROW_CROPS.include?(c) }
      penalty = (slope >= STEEP ? 25 : 8) + (rain.stormy_field? ? STORM_PENALTY : 0)
      [ 100 - (rows * penalty), 0 ].max
    end

    # How often it pours at the pin (GPM IMERG), and in which months.
    def rain_fact(facts)
      return unless rain.present?

      stormy = rain.stormy_months.map(&:month)
      values = { days: rain.heavy_days_per_year, years: rain.years }
      key = stormy.any? ? "heavy_rain" : "heavy_rain_rare"
      values[:months] = stormy if stormy.any?
      facts << Fact.new(key: key, values: values, source: Weather::RainExtremes::SOURCE)
    end

    def rain = (@rain ||= Weather::RainExtremes.new(@field.observation("gpm_imerg")))

    # How wet the root zone was over the last year against its usual range (SMAP).
    def soil_moisture_fact(facts)
      return unless soil.present?

      dry = soil.dry_months.map { |m| m.label_date.month }
      key, values = dry.any? ? [ "soil_dry", { months: dry } ] : [ "soil_usual", {} ]
      facts << Fact.new(key: key, values: values, source: Weather::SoilMoisture::SOURCE)
    end

    def soil = (@soil ||= Weather::SoilMoisture.new(@field.observation("smap")))

    # Cover crops the field has already had: the soil-health habit the timeline's windows build on.
    def cover_history_fact(facts)
      covers = @field.cover_crops.last(3)
      return if covers.empty?

      facts << Fact.new(key: "cover_history", values: { crops: covers.map(&:crop_name).uniq.to_sentence, years: covers.map(&:season_year).uniq.to_sentence },
                        source: nil)
    end

    # A second crop the field grows after one of this strategy's main crops; or the gap
    # when the farmer says two crops a year but none is recorded.
    def double_crop_fact(crops, facts, gaps)
      doubles = @field.double_crops
      if doubles.empty?
        gaps << "second_crop" if @record.cropping_intensity_two_per_year?
        return
      end

      crops.uniq.each do |crop|
        second = doubles[crop] or next
        facts << Fact.new(key: "double_crop", values: { main: crop, second: Crops::Agronomy.find(second)&.key || second.crop_name }, source: nil)
      end
    end

    # Whether the plants at the pin were short of water over the last year (ECOSTRESS).
    def water_stress_fact(facts)
      return unless stress.present?

      stressed = stress.stressed_months.map { |m| m.label_date.month }
      key, values = stressed.any? ? [ "water_stress", { months: stressed } ] : [ "water_stress_none", {} ]
      facts << Fact.new(key: key, values: values, source: Weather::WaterStress::SOURCE)
    end

    def stress = (@stress ||= Weather::WaterStress.new(@field.observation("ecostress")))

    # The region's water bank against 2004-2009 (GRACE): what wells and canals draw on.
    def water_storage_fact(facts)
      return unless storage.present?

      values = { cm: storage.recent_cm.abs, trend: storage.trend }
      key = if storage.recent_cm <= Weather::WaterStorage::LOW_CM then "storage_low"
      elsif storage.recent_cm.negative? then "storage_below"
      else "storage_above"
      end
      facts << Fact.new(key: key, values: values, source: Weather::WaterStorage::SOURCE)
    end

    def storage = (@storage ||= Weather::WaterStorage.new(@field.observation("grace")))

    # The last year's vegetation against its 20-year normal at the pin (MODIS).
    def vegetation_fact(facts)
      normal = Fields::VegetationNormal.new(@field.observation("modis"))
      return unless normal.present?

      below = normal.below.map { |m| m[5, 2].to_i }
      key, values = below.any? ? [ "vegetation_below", { months: below, years: normal.years } ] : [ "vegetation_usual", { years: normal.years } ]
      facts << Fact.new(key: key, values: values, source: Fields::VegetationNormal::SOURCE)
    end

    # Fewer different crops and machinery the farm already has mean less work.
    def workload(crops)
      distinct = crops.uniq.size
      grains = crops.any? { |c| SMALL_GRAINS.include?(Crops::Agronomy.gaez_name(c)) }
      score = 100 - ((distinct - 1) * 15)
      score -= 20 if grains && !harvester?
      score.clamp(0, 100)
    end

    def why(key, crops, scores) = { key: key, crop: crops.first, lead: scores.compact.max_by { |c, v| v * weights[c] }&.first }

    def benefits(strategy, current)
      strategy.scores.filter_map do |criterion, value|
        base = current.scores[criterion]
        criterion if value && base && value - base >= 10
      end
    end

    def risks(crops, scores)
      list = []
      list << "dry" if !@record.uses_irrigation? && crops.uniq.any? { |c| (n = water_need(c)) && n.rain_mm < n.crop_mm * DRY_SHARE }
      list << "water_storage" if @record.uses_irrigation? && storage.depleted?
      list << "dry_soil" if !@record.uses_irrigation? && soil.dry_months.size >= DRY_SOIL_MONTHS
      list << "low_suitability" if crops.any? { |c| (r = @potential.for(c)) && r.suitability && r.suitability < LOW_SUITABILITY }
      list << "harvester" if crops.any? { |c| SMALL_GRAINS.include?(Crops::Agronomy.gaez_name(c)) } && !harvester?
      list << "same_family" if scores["pest_break"].to_i < 75
      list << "heavy_rain" if rain.stormy_field? && crops.any? { |c| ROW_CROPS.include?(c) }
      list << "establishment" if crops.include?("medicago-sativa")
      new_crops = crops.uniq - grown
      list << "new_crop" if new_crops.any? && @profile&.risk_tolerance_cautious?
      list << "contract" if new_crops.any? && (Array(@profile&.market_channels) & BOUND_CHANNELS).any?
      list
    end

    # The crop's FAO-56 water need, sown when the field last sowed it (its recorded
    # planting month), else in FAO-56's month for the hemisphere.
    def water_need(crop)
      @water_needs ||= {}
      @water_needs.fetch(crop) do
        @water_needs[crop] = Crops::WaterNeed.for(crop, observation: @power, latitude: @record.latitude, planting_month: sown_in(crop))
      end
    end

    def sown_in(crop)
      @record.field_crops.select { |c| c.planting_month && key_of(c) == crop }.max_by(&:season_year)&.planting_month
    end

    # The best-suited crop at the pin among these GAEZ crops (outside the
    # given families), or the first known one when GAEZ has not answered.
    def best_of(gaez_names, exclude: [])
      ranked = @potential.ranked.select { |row| gaez_names.include?(row.gaez) }.map(&:entry)
      known = gaez_names.filter_map { |name| Crops::Agronomy.entries.values.find { |e| e.gaez == name } }
      (ranked + known).compact.find { |entry| !Array(exclude).include?(entry.family) }&.key
    end

    def suitable?(gaez_name) = @potential.rows.any? { |r| r.gaez == gaez_name && r.suitability.to_i >= LOW_SUITABILITY }
    def harvester? = Array(@profile&.equipment).include?("harvester")
    # Catalog keys of every crop the field has had (main crops, past seasons).
    def grown = (@grown ||= @field.history.values.filter_map { |c| key_of(c) }.uniq)
    def key_of(crop) = crop && (Crops::Agronomy.find(crop)&.key || crop.crop_key)
  end
end
