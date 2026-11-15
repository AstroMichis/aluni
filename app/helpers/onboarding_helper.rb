# frozen_string_literal: true

# View helpers for the Ask Aluni chat: the one-line summary of what a turn
# saved (the toast with Undo), the profile preview rows, and the transcript.
#
# Applied shape (Onboarding::ApplyProposalService, carried by ReplyService's
# payload[:applied] and session.last_applied["applied"]): one entry per key,
#   { "profile.budget_level" => "low", "farm.name" => "Finca Ana", "field.area" => 12.5,
#     "field.area_unit" => "hectares", "field.soil.texture" => "medium",
#     "crops.2025.main" => { "season_year" => 2025, "role" => "main", "crop_name" => "Corn", ... } }
# The pin travels as five field.* keys and is summarised as one "Location" item.
module OnboardingHelper
  # Attributes whose values are enum or allowlist slugs with a label under onboarding.values.<attribute>.
  LABELLED_ATTRIBUTES = %w[
    role experience team units land_tenure budget_level risk_tolerance segment
    location_confidence location_source area_unit irrigation water_source cropping_intensity source crop_role
    goals equipment livestock market_channels practices texture depth drainage salinity fertility problems
  ].freeze
  PIN_KEYS = Onboarding::Allowlist::LOCATION_KEYS.map { |key| "field.#{key}" }.freeze

  # "Saved: Area 12.5 hectares, Irrigation Drip, Soil texture Medium (loam)."
  def applied_summary(applied)
    items = applied_items((applied || {}).to_h.deep_stringify_keys)
    return t("app.onboarding.show.applied_generic") if items.empty?

    t("app.onboarding.show.applied", items: items.join(", "))
  end

  # One label-and-value phrase per saved fact, the pin once, the area with its unit.
  def applied_items(data)
    data.filter_map do |key, value|
      case key
      when "field.latitude"
        "#{field_label('field', 'location')} #{pin_summary(applied_pin(data))}"
      when *PIN_KEYS
        nil
      when "field.area"
        "#{field_label('field', 'area')} #{applied_area(value, data['field.area_unit'])}"
      when "field.area_unit"
        data.key?("field.area") ? nil : "#{field_label('field', 'area_unit')} #{value_label('area_unit', value)}"
      when /\Afield\.soil\.(\w+)\z/
        soil_key = Regexp.last_match(1)
        "#{field_label('field.soil', soil_key)} #{format_value(soil_key, value)}"
      when /\Acrops\.(-?\d+)\.(\w+)\z/
        year, role = Regexp.last_match(1).to_i, Regexp.last_match(2)
        "#{t('onboarding.field_labels.crops', year: year, role: value_label('crop_role', role))} #{crop_summary(section_hash(value))}"
      when /\A(profile|farm|field)\.(\w+)\z/
        section, attribute = Regexp.last_match(1), Regexp.last_match(2)
        "#{field_label(section, attribute)} #{format_value(attribute, value)}"
      end
    end
  end

  # "42.0000, -93.7500 (Near Ames)" for a pin given as a field hash.
  def pin_summary(field)
    field = section_hash(field)
    pin = preview_pin({ latitude: field["latitude"], longitude: field["longitude"] })
    [ pin, field["place_label"].presence && "(#{field["place_label"]})" ].compact.join(" ").presence || preview_unknown
  end

  # A slug (or list of slugs) to its label, falling back to a humanised slug.
  def value_label(attribute, value)
    return value.map { |v| value_label(attribute, v) }.join(", ") if value.is_a?(Array)

    t("onboarding.values.#{attribute}.#{value}", default: value.to_s.humanize)
  end

  def format_value(attribute, value)
    case value
    when nil then preview_unknown
    when true then t("onboarding.values.boolean.affirmative")
    when false then t("onboarding.values.boolean.negative")
    when Array then value.empty? ? preview_unknown : (LABELLED_ATTRIBUTES.include?(attribute.to_s) ? value_label(attribute, value) : value.join(", "))
    when Hash then value.map { |k, v| "#{k}: #{format_value(k, v)}" }.join(", ")
    when Numeric then number_with_precision(value, precision: 2, strip_insignificant_zeros: true)
    else
      LABELLED_ATTRIBUTES.include?(attribute.to_s) ? value_label(attribute, value) : value.to_s
    end
  end

  # "Corn (Zea mays), planted Apr, harvest Oct"
  def crop_summary(crop)
    name = [ crop["crop_name"], crop["scientific_name"].presence && "(#{crop["scientific_name"]})" ].compact.join(" ")
    months = crop_months(crop["planting_month"], crop["harvest_month"])
    [ name, months ].compact.join(", ")
  end

  def crop_months(planting, harvest)
    return nil if planting.blank? && harvest.blank?

    t("onboarding.field_labels.crop_months", planting: month_name(planting), harvest: month_name(harvest))
  end

  def month_name(month)
    return preview_unknown if month.blank?

    I18n.t("date.abbr_month_names")[month.to_i] || month.to_s
  end

  # --- the profile preview --------------------------------------------------

  def preview_unknown = t("app.onboarding.show.preview.unknown")

  def preview_rows(snapshot)
    profile = snapshot[:profile] || {}
    farm = snapshot[:farm] || {}
    field = snapshot[:field] || {}
    [
      preview_row("farm", farm[:name]),
      preview_row("pin", preview_pin(field)),
      preview_row("area", preview_area(field)),
      preview_row("irrigation", field[:irrigation] && value_label("irrigation", field[:irrigation])),
      preview_row("water", field[:water_source] && value_label("water_source", field[:water_source])),
      preview_row("soil", preview_soil(field[:soil])),
      preview_row("crops", preview_crops(snapshot[:crops])),
      preview_row("role", profile[:role] && value_label("role", profile[:role])),
      preview_row("experience", profile[:experience] && value_label("experience", profile[:experience])),
      preview_row("team", profile[:team] && value_label("team", profile[:team])),
      preview_row("budget", profile[:budget_level] && value_label("budget_level", profile[:budget_level])),
      preview_row("goals", profile[:goals].presence && value_label("goals", profile[:goals])),
      preview_row("segment", profile[:segment] && value_label("segment", profile[:segment]))
    ]
  end

  # The short recap on the home screen: farm, pin, area, segment, goals.
  def snapshot_recap_rows(snapshot)
    profile = snapshot[:profile] || {}
    field = snapshot[:field] || {}
    [
      { label: t("app.home.show.recap.farm"), value: (snapshot[:farm] || {})[:name].presence || preview_unknown },
      { label: t("app.home.show.recap.pin"), value: preview_pin(field) || preview_unknown },
      { label: t("app.home.show.recap.area"), value: preview_area(field) || preview_unknown },
      { label: t("app.home.show.recap.segment"), value: profile[:segment] ? value_label("segment", profile[:segment]) : preview_unknown },
      { label: t("app.home.show.recap.goals"), value: profile[:goals].presence ? value_label("goals", profile[:goals]) : preview_unknown }
    ]
  end

  def preview_pin(field)
    return nil unless field && field[:latitude] && field[:longitude]

    t("app.onboarding.show.preview.pin_value", latitude: format("%.4f", field[:latitude]), longitude: format("%.4f", field[:longitude]))
  end

  def preview_area(field)
    return nil unless field && field[:area]

    "#{number_with_precision(field[:area], precision: 2, strip_insignificant_zeros: true)} #{value_label('area_unit', field[:area_unit])}"
  end

  def preview_soil(soil)
    return nil if soil.blank?

    soil.filter_map { |key, value| value.present? && "#{field_label('field.soil', key)}: #{format_value(key, value)}" }.join("; ").presence
  end

  def preview_crops(crops)
    return nil if crops.blank?

    crops.first(6).map { |crop| "#{crop[:season_year]}: #{crop[:crop_name]}" }.join(", ")
  end

  # --- the transcript --------------------------------------------------------

  # Turns stored on the row, normalised to { role: "user" | "assistant", text: }.
  # Accepts the Gemini-style "model" role and a "content" key as synonyms.
  def transcript_turns(transcript)
    Array(transcript).filter_map do |turn|
      next unless turn.is_a?(Hash)

      turn = turn.stringify_keys
      text = turn["text"] || turn["content"] || Array(turn["parts"]).filter_map { |part| part.is_a?(Hash) ? part["text"] : part }.join("\n")
      next if text.blank?

      { role: turn["role"].to_s == "user" ? "user" : "assistant", text: text.to_s }
    end
  end

  def onboarding_topics = Onboarding::Topics.keys

  def topic_title(key) = t(Onboarding::Topics.title_key(key))

  private

  def section_hash(section) = section.is_a?(Hash) ? section : {}

  # The five pin keys of an applied hash as one field hash for pin_summary.
  def applied_pin(data)
    Onboarding::Allowlist::LOCATION_KEYS.to_h { |key| [ key, data["field.#{key}"] ] }
  end

  def applied_area(area, unit)
    number = area.is_a?(Numeric) ? format_value("area", area) : area.to_s
    unit.present? ? "#{number} #{value_label('area_unit', unit)}" : number
  end

  def preview_row(key, value) = { label: t("app.onboarding.show.preview.#{key}"), value: value.presence || preview_unknown }

  def field_label(section, key)
    t("onboarding.field_labels.#{section}.#{key}", default: key.to_s.humanize)
  end
end
