module Crops
  # The built-in bilingual crop list (config/crops/common.yml), loaded once and
  # looked up without accents or case: "maíz", "Maiz" and "elote" all find
  # maize. Feeds the finder's datalist (.all) and NormalizeService (.find and
  # .search), so a crop the list knows never costs a Gemini call.
  class Catalog
    PATH = Rails.root.join("config/crops/common.yml")
    DEFAULT_LIMIT = 8

    class << self
      def instance = @instance ||= new(YAML.load_file(PATH))

      def reset! = @instance = nil

      def find(text, locale: I18n.locale) = instance.find(text, locale: locale)
      def search(text, locale: I18n.locale, limit: DEFAULT_LIMIT) = instance.search(text, locale: locale, limit: limit)
      def all(locale: I18n.locale) = instance.all(locale: locale)

      # Lowercase, no accents, one space between words: the key every lookup uses.
      def fold(text)
        ActiveSupport::Inflector.transliterate(text.to_s, "").downcase.squish
      end
    end

    def initialize(data)
      @crops = data.to_h.map do |key, row|
        row = row.to_h.stringify_keys
        names = I18n.available_locales.map(&:to_s).index_with { |locale| row[locale].to_s }
        aliases = (Array(row["aliases"]) + names.values).map { |a| self.class.fold(a) }.reject(&:empty?).uniq
        { key: key.to_s, scientific_name: row["scientific"].to_s, names: names, aliases: aliases }
      end
      @by_alias = @crops.each_with_object({}) do |crop, index|
        crop[:aliases].each { |a| index[a] ||= crop }
      end
    end

    # An exact match on a name or an alias, or nil.
    def find(text, locale:)
      crop = @by_alias[self.class.fold(text)]
      crop && present(crop, locale)
    end

    # Crops whose names or aliases start with the text, then those with a word
    # that starts with it; up to limit, each key once.
    def search(text, locale:, limit: DEFAULT_LIMIT)
      needle = self.class.fold(text)
      return [] if needle.empty?

      prefix = @crops.select { |crop| crop[:aliases].any? { |a| a.start_with?(needle) } }
      words = @crops.select { |crop| crop[:aliases].any? { |a| a.split.any? { |w| w.start_with?(needle) } } }
      (prefix + words).uniq.first(limit).map { |crop| present(crop, locale) }
    end

    # Every crop, sorted by its name in the locale.
    def all(locale:)
      @crops.map { |crop| present(crop, locale) }.sort_by { |crop| self.class.fold(crop[:crop_name]) }
    end

    private

    def present(crop, locale)
      name = crop[:names][locale.to_s].presence || crop[:names][I18n.default_locale.to_s]
      { key: crop[:key], crop_name: name, scientific_name: crop[:scientific_name] }
    end
  end
end
