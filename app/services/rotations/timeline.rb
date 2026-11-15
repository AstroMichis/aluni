# frozen_string_literal: true

module Rotations
  # The next three seasons of a strategy, month by month: when the soil
  # carries a crop and when it is bare, against the field's usual weather.
  #
  # - The weather strip is the same every year (normals): frost months (NASA
  #   POWER frost days), heat months (the month can reach HEAT_C), dry months
  #   (rain under half the FAO-56 reference evapotranspiration) and stormy
  #   months (heavy-rain days from GPM IMERG, Weather::RainExtremes).
  # - Each crop grows from its planting month for the length of its FAO-56
  #   stages, the field's own months for its current crop, all year for a
  #   perennial stand; a season that crosses the new year carries on into the
  #   next one. A crop without a known season leaves its months unknown.
  # - A vulnerable month is a bare month under storms, drought or frost: the
  #   windows the challenge asks to show, and where a cover crop would help.
  #
  # Months are counted on one line from January of the first season
  # (index 0) to December of the third (index 35).
  class Timeline
    MONTHS = 12
    HORIZON = Comparator::HORIZON
    FROST_DAYS = 2.0   # frost days in a typical month from which it is a frost month
    HEAT_C = 35.0      # the month's highest temperature on record reaches it
    DRY_SHARE = 0.5    # rain under half the reference evapotranspiration
    RISKS = %w[storm dry frost heat].freeze
    EXPOSING = %w[storm dry frost].freeze # what bare soil suffers from (heat is the crop's risk)
    DAYS_PER_MONTH = 30.4
    # Cover crops for a bare window of COVER_MONTHS or more, from the catalog:
    # cereal rye where it freezes, oats in a cool window, cowpea (a legume) in
    # a warm one. "Cool" is a mean temperature under COOL_C over the window.
    COVER_MONTHS = 2
    COOL_C = 12.0
    COVERS = { "frost" => "secale-cereale", "cool" => "avena-sativa", "warm" => "vigna-unguiculata" }.freeze

    Month = Struct.new(:index, :year, :month, :state, :crop, :risks, keyword_init: true) do
      def bare? = state == "bare"
      def growing? = state == "crop"
      def vulnerable? = bare? && risks.intersect?(EXPOSING)
    end
    # A run of bare months a cover crop could fill: what to sow, and whether
    # the window is so dry that the cover needs irrigation to establish.
    Window = Struct.new(:months, :cover, :kind, :dry, keyword_init: true) do
      def first = months.first
      def last = months.last
      def exposed = months.count(&:vulnerable?)
      # A cover takes about a month to close over the soil: the first month stays exposed.
      def protected = months.drop(1).count(&:vulnerable?)
      def indexes = months.map(&:index)
    end
    Line = Struct.new(:crops, :months, :windows, keyword_init: true) do
      def seasons = months.each_slice(MONTHS).to_a
      def bare = months.count(&:bare?)
      def vulnerable = months.select(&:vulnerable?)
      def stormy_bare = months.count { |m| m.bare? && m.risks.include?("storm") }
      def known? = months.any? { |m| m.state != "unknown" }
      # Exposed months left once every cover window is sown (each window's first month still counts).
      def exposed_with_cover = vulnerable.size - windows.sum(&:protected)
      def window_for(month) = windows.find { |w| w.indexes.include?(month.index) }
    end

    def initialize(field, first_year: Date.current.year + 1)
      @field = field
      @record = field.record
      @first_year = first_year
      @rain = Weather::RainExtremes.new(field.observation("gpm_imerg"))
      power = field.observation("nasa_power")
      @climatology = power&.ok? ? power.payload["climatology"].to_h : {}
      @elevation = power&.ok? ? power.payload["elevation"] : nil
    end

    # { 1 => ["frost"], 7 => ["storm", "heat"], ... } for the 12 calendar months.
    def weather
      @weather ||= (1..MONTHS).to_h { |m| [ m, RISKS.select { |risk| send(:"#{risk}?", m) } ] }
    end

    def weather? = weather.values.any?(&:any?) || @climatology.any?

    def for(crops)
      states = Array.new(MONTHS * HORIZON) { [ "bare", nil ] }
      known = Array.new(MONTHS * HORIZON, true)
      carry_current(states)
      crops.each_with_index do |crop, season|
        window = window(crop, season)
        if window.nil?
          (season * MONTHS...(season + 1) * MONTHS).each { |i| known[i] = false unless states[i].first == "crop" }
          next
        end
        window.each { |i| states[i] = [ "crop", crop ] if i < states.size }
      end
      add_second_crops(crops, states)
      months = states.each_with_index.map do |(state, crop), i|
        month = (i % MONTHS) + 1
        Month.new(index: i, year: @first_year + (i / MONTHS), month: month,
                  state: known[i] || state == "crop" ? state : "unknown", crop: crop, risks: weather[month])
      end
      Line.new(crops: crops, months: months, windows: cover_windows(months))
    end

    private

    # A season whose main crop the field has double-cropped before gets that
    # second crop too: in its own months when the record has them, else from
    # the month after the main harvest for its FAO-56 length. It never covers
    # a month a main crop holds.
    def add_second_crops(crops, states)
      crops.each_with_index do |crop, season|
        second = @field.double_crops[key_of(crop)] or next
        main = window(crop, season) or next
        planting, length = second_months(second)
        next unless length

        start = planting ? (season * MONTHS) + planting - 1 : main.last + 1
        start += MONTHS if planting && start <= main.first
        (start...(start + length)).each do |i|
          states[i] = [ "crop", key_of(second) ] if i < states.size && states[i].first != "crop"
        end
      end
    end

    def second_months(second)
      return [ second.planting_month, ((second.harvest_month - second.planting_month) % MONTHS) + 1 ] if second.planting_month && second.harvest_month

      fao = Crops::Agronomy.find(second)&.fao56
      [ nil, fao && (fao["stages"].sum / DAYS_PER_MONTH).ceil ]
    end

    # Runs of COVER_MONTHS or more bare months, each with the cover that fits its weather.
    def cover_windows(months)
      months.chunk_while { |a, b| a.bare? && b.bare? }.select { |run| run.first.bare? && run.size >= COVER_MONTHS }.map do |run|
        temps = run.filter_map { |m| normal("T2M", m.month) }
        kind = if run.any? { |m| m.risks.include?("frost") } then "frost"
        elsif temps.any? && (temps.sum / temps.size) < COOL_C then "cool"
        else "warm"
        end
        Window.new(months: run, cover: COVERS.fetch(kind), kind: kind, dry: run.all? { |m| m.risks.include?("dry") })
      end
    end

    # Line indexes a crop of the given season (0, 1, 2) covers, or nil when unknown.
    def window(crop, season)
      return (season * MONTHS...(season + 1) * MONTHS).to_a if Comparator::PERENNIALS.include?(key_of(crop))

      planting, length = season_of(crop)
      return unless planting && length

      start = (season * MONTHS) + planting - 1
      (start...(start + length)).to_a
    end

    # The current crop's months that run into the first season (a southern
    # summer crop planted in October is still growing in January).
    def carry_current(states)
      current = @field.current_crop
      return unless current

      planting, length = season_of(key_of(current))
      return unless planting && length

      start = ((current.season_year - @first_year) * MONTHS) + planting - 1
      (start...(start + length)).each do |i|
        states[i] = [ "crop", key_of(current) ] if i >= 0
      end
    end

    # [planting month, months in the ground] from the field's own record for
    # its current crop, else FAO-56 (planting month shifted south of the tropics).
    def season_of(crop)
      own = @field.current_crop
      if own && key_of(own) == key_of(crop) && own.planting_month && own.harvest_month
        return [ own.planting_month, ((own.harvest_month - own.planting_month) % MONTHS) + 1 ]
      end

      fao = Crops::Agronomy.find(crop)&.fao56
      return unless fao

      planting = Crops::WaterNeed.default_month(fao["planting_month"], @record.latitude)
      [ planting, (fao["stages"].sum / DAYS_PER_MONTH).ceil ]
    end

    def storm?(month) = @rain.months.find { |m| m.month == month }&.stormy? || false
    def frost?(month) = normal("FROST_DAYS", month).to_f >= FROST_DAYS
    def heat?(month) = normal("T2M_MAX", month).to_f >= HEAT_C

    def dry?(month)
      rain = normal("PRECTOTCORR", month)
      demand = et0&.dig(month)
      rain && demand&.positive? ? rain < demand * DRY_SHARE : false
    end

    def et0
      return @et0 if defined?(@et0)

      @et0 = @elevation && @record.latitude ? Weather::Et0.monthly(@climatology, latitude: @record.latitude, elevation: @elevation) : nil
    end

    def normal(parameter, month) = @climatology.dig(parameter, Weather::Season::MONTHS[month - 1])
    def key_of(crop) = crop && (Crops::Agronomy.find(crop)&.key || (crop.respond_to?(:crop_key) ? crop.crop_key : crop))
  end
end
