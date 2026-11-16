# frozen_string_literal: true

module Weather
  # When the weather at a field's pin favours a pest or disease, so the farmer
  # knows when to walk the field. Weather that suits a pest is not the pest:
  # these windows say when to scout, never that a crop will be hit. Only the
  # rules that daily NASA POWER values can run (docs/data_sources/pest_weather_rules.md),
  # operationalised as in docs/proposal/validation/v5_pests.rb, where the Ames
  # hindcast found every rule leaning the right way but none significant.
  #
  #   tar spot       corn; 30-day mean T2M within 18-23 °C, 15 Jun to 15 Sep
  #                  (Scientific Reports 2023)
  #   fall armyworm  corn, sorghum; degree-days above 12.57 °C May to October and
  #                  the generations they allow (391 DD each) once it arrives
  #                  (du Plessis et al. 2020); the arrival needs trap data
  #
  # The leaf diseases that need hourly humidity or leaf wetness (gray leaf spot,
  # northern corn leaf blight, Asian soybean rust, the wheat rusts) are listed
  # as rules not run, the gap the field station would close.
  class ScoutWindows
    TAR_SPOT = { crops: %w[zea-mays], low: 18.0, high: 23.0, days: 30, from: [ 6, 15 ], to: [ 9, 15 ] }.freeze
    ARMYWORM = { crops: %w[zea-mays sorghum-bicolor], base: 12.57, generation: 391.0, months: (5..10) }.freeze
    HOURLY = { "zea-mays" => %w[gray_leaf_spot northern_corn_leaf_blight], "glycine-max" => %w[soybean_rust],
               "triticum-aestivum" => %w[wheat_rusts fusarium_head_blight], "hordeum-vulgare" => %w[fusarium_head_blight] }.freeze
    SOURCE = "NASA POWER"

    Window = Struct.new(:rule, :favourable_days, :first, :last, :runs, :active, keyword_init: true)
    Armyworm = Struct.new(:degree_days, :generations, keyword_init: true)

    # crops: the crop keys on the field this season ("zea-mays", ...).
    def self.for(season, crops)
      new(season, Array(crops).compact)
    end

    attr_reader :season, :crops

    def initialize(season, crops)
      @season = season
      @crops = crops.uniq
    end

    def any? = tar_spot.present? || armyworm.present?
    def watched? = (crops & (TAR_SPOT[:crops] + ARMYWORM[:crops])).any?

    # The hourly rules that would apply to these crops but are not run.
    def unrun = crops.flat_map { |c| HOURLY.fetch(c, []) }.uniq

    # Window or nil when no corn is on the field or no day was favourable.
    def tar_spot
      return @tar_spot if defined?(@tar_spot)
      return @tar_spot = nil unless (crops & TAR_SPOT[:crops]).any?

      days = season.days
      favourable = days.each_index.filter_map do |i|
        next if i < TAR_SPOT[:days] - 1

        day = days[i]
        next unless in_window?(day.date)

        mean = days[(i - TAR_SPOT[:days] + 1)..i].sum(&:tmean) / TAR_SPOT[:days]
        day.date if mean.between?(TAR_SPOT[:low], TAR_SPOT[:high])
      end
      return @tar_spot = nil if favourable.empty?

      runs = favourable.chunk_while { |a, b| b == a + 1 }.to_a
      @tar_spot = Window.new(rule: "tar_spot", favourable_days: favourable.size, first: favourable.first,
                             last: favourable.last, runs: runs, active: favourable.last == season.to)
    end

    # Armyworm or nil when neither corn nor sorghum is on the field.
    def armyworm
      return @armyworm if defined?(@armyworm)
      return @armyworm = nil unless (crops & ARMYWORM[:crops]).any?

      dd = season.days.select { |d| ARMYWORM[:months].cover?(d.date.month) }
                 .sum { |d| [ ((d.tmax + d.tmin) / 2) - ARMYWORM[:base], 0 ].max }
      @armyworm = Armyworm.new(degree_days: dd.round, generations: (dd / ARMYWORM[:generation]).round(1))
    end

    # Season::Event rows for the alerts timeline: one per favourable run.
    def events
      Array(tar_spot&.runs).map { |run| Season::Event.new(kind: "scout", from: run.first, to: run.size > 1 ? run.last : nil, value: run.size) }
    end

    private

    def in_window?(date)
      from = Date.new(date.year, *TAR_SPOT[:from])
      to = Date.new(date.year, *TAR_SPOT[:to])
      date.between?(from, to)
    end
  end
end
