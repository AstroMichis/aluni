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

    def initialize(field, profile:)
      @field = field
      @record = field.record
      @profile = profile
      @potential = Crops::Potential.new(field.observation("gaez"))
      @power = field.observation("nasa_power")
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

    # GAEZ suitability (0-10000) averaged over the seasons' crops.
    def crop_fit(crops, facts, gaps)
      values = crops.filter_map do |crop|
        row = @potential.for(crop)
        facts << Fact.new(key: "suitability", values: { crop: crop, class: row.suitability_class }, source: "FAO GAEZ v4") if row&.suitability_class
        row&.suitability
      end
      gaps << "suitability" if values.size < crops.size
      values.any? ? (values.sum / values.size / 100.0).round : nil
    end

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
      score = @record.uses_irrigation? ? 60 + (40 * share) : 100 * share
      score.clamp(0, 100).round
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

    def water_need(crop)
      @water_needs ||= {}
      @water_needs.fetch(crop) do
        @water_needs[crop] = Crops::WaterNeed.for(crop, observation: @power, latitude: @record.latitude)
      end
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
