# frozen_string_literal: true

module Crops
  # Basic rotation rules over a field's seasons (its FieldCrop history and
  # the plan): the same family two seasons running, the same crop three or
  # more running, and no legume in the last four seasons. Plain agronomic
  # rules of thumb that flag what to look at; comparing strategies is the
  # rotation engine's job, not this. Crops compare by catalog key, so "Maíz",
  # "Corn" and Zea mays are one crop.
  class RotationCheck
    Finding = Struct.new(:kind, :years, :crop, keyword_init: true)

    LEGUME_WINDOW = 4

    # seasons: [[label, crop], ...] oldest first; crop is a FieldCrop or a name.
    def initialize(seasons)
      @seasons = seasons.reject { |_, crop| crop.blank? }
    end

    def findings
      repeats + monoculture + missing_legume
    end

    private

    def key(crop) = Agronomy.find(crop)&.key || (crop.respond_to?(:crop_key) ? crop.crop_key : crop.to_s.parameterize)

    def repeats
      @seasons.each_cons(2).filter_map do |(year_a, a), (year_b, b)|
        family = Agronomy.family(a)
        Finding.new(kind: "same_family", years: [ year_a, year_b ], crop: b) if family && family == Agronomy.family(b)
      end
    end

    def monoculture
      @seasons.chunk_while { |(_, a), (_, b)| key(a) == key(b) }.select { |run| run.size >= 3 }
              .map { |run| Finding.new(kind: "monoculture", years: run.map(&:first), crop: run.first.last) }
    end

    def missing_legume
      recent = @seasons.last(LEGUME_WINDOW)
      return [] if recent.size < LEGUME_WINDOW || recent.any? { |_, crop| Agronomy.legume?(crop) }

      [ Finding.new(kind: "no_legume", years: recent.map(&:first)) ]
    end
  end
end
