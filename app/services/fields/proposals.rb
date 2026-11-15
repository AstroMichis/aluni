# frozen_string_literal: true

module Fields
  # How a public source's value becomes the farmer's answer when they tap
  # "Looks right" (config/field_profile.yml `propose:`). Each returns a value
  # in the onboarding vocabulary (Onboarding::Allowlist), or nil.
  module Proposals
    # SSURGO drainage classes to ECOCROP's poor / well / excessive.
    DRAINAGE = {
      "Very poorly drained" => "poor", "Poorly drained" => "poor", "Somewhat poorly drained" => "poor",
      "Moderately well drained" => "well", "Well drained" => "well",
      "Somewhat excessively drained" => "excessive", "Excessively drained" => "excessive"
    }.freeze
    HEAVY_CLAY = 40   # % clay from which a soil handles as heavy (clay, silty clay)
    LIGHT_SAND = 70   # % sand from which it handles as light (sand, loamy sand)

    module_function

    def call(kind, values)
      case kind
      when "texture_class" then texture_class(values["sand"], values["clay"])
      when "drainage_class" then DRAINAGE[values["value"].to_s.strip]
      when "number" then values["value"].is_a?(Numeric) ? values["value"].round(1) : nil
      when "cdl_history" then values["years"].presence
      end
    end

    # Topsoil sand and clay (%) to ECOCROP's heavy / medium / light texture.
    def texture_class(sand, clay)
      return nil unless sand.is_a?(Numeric) && clay.is_a?(Numeric)
      return "heavy" if clay >= HEAVY_CLAY
      return "light" if sand >= LIGHT_SAND

      "medium"
    end
  end
end
