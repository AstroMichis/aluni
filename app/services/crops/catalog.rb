# frozen_string_literal: true

require "yaml"

module Crops
  # config/crops.yml: each crop's family and plant shape.
  module Catalog
    PATH = Rails.root.join("config/crops.yml")
    LEGUMES = "fabaceae"

    module_function

    def all = (@all ||= YAML.safe_load(File.read(PATH)).freeze)
    def family(crop) = all.dig(crop.to_s, "family")
    def shape(crop) = all.key?(crop.to_s) ? all.dig(crop.to_s, "shape") : "leafy"
    def legume?(crop) = family(crop) == LEGUMES
  end
end
