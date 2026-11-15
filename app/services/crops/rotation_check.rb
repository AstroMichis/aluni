# frozen_string_literal: true

module Crops
  # Basic rotation rules over a field's seasons (history, this season and the
  # plan): the same family two seasons running, the same crop three or more
  # running, and no legume in the last four seasons. Plain agronomic rules of
  # thumb that flag what to look at; the comparison of strategies is the
  # engine's job, not this.
  class RotationCheck
    Finding = Struct.new(:kind, :years, :crop, keyword_init: true)

    LEGUME_WINDOW = 4

    # seasons: [[label, crop], ...] oldest first (label is a year or "plan").
    def initialize(seasons)
      @seasons = seasons.reject { |_, crop| crop.blank? }
    end

    def findings
      repeats + monoculture + missing_legume
    end

    private

    def repeats
      @seasons.each_cons(2).filter_map do |(year_a, a), (year_b, b)|
        family = Catalog.family(a)
        Finding.new(kind: "same_family", years: [ year_a, year_b ], crop: b) if family && family == Catalog.family(b)
      end
    end

    def monoculture
      @seasons.chunk_while { |(_, a), (_, b)| a == b }.select { |run| run.size >= 3 }
              .map { |run| Finding.new(kind: "monoculture", years: run.map(&:first), crop: run.first.last) }
    end

    def missing_legume
      recent = @seasons.last(LEGUME_WINDOW)
      return [] if recent.size < LEGUME_WINDOW || recent.any? { |_, crop| Catalog.legume?(crop) }

      [ Finding.new(kind: "no_legume", years: recent.map(&:first)) ]
    end
  end
end
