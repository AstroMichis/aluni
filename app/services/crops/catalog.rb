# frozen_string_literal: true

require "yaml"

module Crops
  # The crops the screens recognise (config/crops.yml) and, when it has been
  # extracted, their ECOCROP requirements (config/ecocrop.yml, rake
  # ecocrop:extract). A FieldCrop matches by its crop_key (the scientific
  # slug) or, failing that, by its common name in English or Spanish.
  module Catalog
    PATH = Rails.root.join("config/crops.yml")
    ECOCROP_PATH = Rails.root.join("config/ecocrop.yml")
    LEGUMES = "fabaceae"

    Entry = Struct.new(:key, :scientific, :family, :shape, :gaez, :fao56, :requirements, keyword_init: true) do
      def legume? = family == LEGUMES
    end

    module_function

    def raw = (@raw ||= YAML.safe_load(File.read(PATH)).freeze)

    def entries
      @entries ||= begin
        ecocrop = ECOCROP_PATH.exist? ? YAML.safe_load(File.read(ECOCROP_PATH)).to_h : {}
        raw.to_h do |key, body|
          [ key, Entry.new(key: key, scientific: body["scientific"], family: body["family"], shape: body["shape"],
                           gaez: body["gaez"], fao56: body["fao56"], requirements: ecocrop[body["scientific"]]).freeze ]
        end.freeze
      end
    end

    # Common name slug => crop key.
    def aliases = (@aliases ||= raw.flat_map { |key, body| Array(body["aliases"]).map { |name| [ name, key ] } }.to_h.freeze)

    # A FieldCrop, a crop key, a scientific or a common name; nil when unknown.
    def find(crop)
      return entries[crop.crop_key] || find(crop.crop_name) if crop.respond_to?(:crop_key)

      slug = crop.to_s.parameterize
      entries[slug] || entries[aliases[slug]]
    end

    def family(crop) = find(crop)&.family
    def legume?(crop) = find(crop)&.legume? || false
    def shape(crop) = find(crop)&.shape || "leafy"
    def gaez_name(crop) = find(crop)&.gaez

    # FieldCrop attributes for a crop picked from the catalog (its key: the
    # name in this language) or typed by the person (kept as typed).
    def row(crop, season_year)
      entry = find(crop)
      name = entry && crop.to_s == entry.key ? I18n.t("app.crops.names.#{entry.key}", default: entry.scientific) : crop.to_s
      { "crop_name" => name, "scientific_name" => entry&.scientific, "season_year" => season_year, "role" => "main" }.compact
    end

    def reset! = (@raw = @entries = @aliases = nil)
  end
end
