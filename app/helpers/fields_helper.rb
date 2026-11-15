# frozen_string_literal: true

# Presentation for the menu sections on the farmer's own farm: field and crop
# names, reading values (options labelled with the onboarding vocabulary,
# onboarding.values.*), sources and confidence, progress, and the plant
# layout of the illustrated field (app/fields/_plot).
module FieldsHelper
  GROUP_GLYPHS = {
    "place" => "map", "profile" => "team", "resources" => "tasks", "market" => "yield", "goals" => "tips",
    "plot" => "fields", "crop" => "crops", "soil" => "soil", "terrain" => "terrain", "climate" => "weather",
    "history" => "history"
  }.freeze

  # The illustrated field is a wedge (like the menu dial's) seen in
  # perspective: rows narrow towards the bottom edge.
  PLOT_ROWS = [ [ 52, 5, 26, 174 ], [ 78, 4, 40, 160 ], [ 104, 3, 54, 146 ] ].freeze # y, plants, x from, x to

  def plot_plants
    PLOT_ROWS.each_with_index.flat_map do |(y, count, from, to), row|
      Array.new(count) { |i| { x: from + ((to - from) * (i + 0.5) / count), y: y, delay: (row * 4) + i } }
    end
  end

  def group_glyph(group) = GROUP_GLYPHS.fetch(group, "fields")

  # The plant shape of the crop's kind (config/crops/agronomy.yml); nil draws an empty plot.
  def crop_shape(crop) = crop.present? ? Crops::Agronomy.shape(crop) : nil

  # A FieldCrop shows the farmer's own words; a catalog key its name in this language.
  def crop_name(crop)
    return crop.crop_name if crop.respond_to?(:crop_name)

    entry = Crops::Agronomy.find(crop)
    entry ? t("app.crops.names.#{entry.key}", default: entry.scientific) : crop.to_s
  end

  def plot_name(field) = field.name || t("app.fields.untitled", number: field.record.position + 1)

  def field_area(field)
    return t("app.fields.no_area") if field.record.area.blank?

    t("app.fields.units.#{field.record.area_unit}", value: number_with_precision(field.record.area, precision: 2, strip_insignificant_zeros: true))
  end

  def hectares(value) = t("app.fields.units.hectares", value: number_with_precision(value, precision: 1, strip_insignificant_zeros: true))

  def datum_label(datum) = t("app.fields.data.#{datum.key}.label")

  def option_label(datum, option)
    datum.months ? t("date.month_names")[option.to_i] : value_label(datum.values_attr, option)
  end

  # What a card shows: the value, or what is missing.
  def reading_text(reading)
    return t("app.fields.states.#{reading.state}") unless reading.known?

    datum = reading.datum
    values = reading.values.transform_values { |value| reading_value(datum, value) }
    # The value template fits the source's values (sand and clay); the
    # farmer's own answer (a texture class) reads on its own.
    fits = datum.observation.empty? || reading.values.keys.sort == datum.observation.keys.sort
    return values.values.join(", ") unless fits

    t("app.fields.data.#{datum.key}.value", **values.symbolize_keys, default: values.values.join(", "))
  end

  # What "Looks right" would save, in the onboarding vocabulary.
  def proposal_text(reading)
    proposal = reading.proposal
    return if proposal.nil?
    return proposal.sort.map { |year, crop| "#{year}: #{crop}" }.join(" · ") if proposal.is_a?(Hash)

    reading_value(reading.datum, proposal)
  end

  # Where it comes from: the source and its confidence (nothing for the person's own answer).
  def reading_origin(reading)
    return if reading.source.nil? && reading.known?

    sources = reading.source ? [ reading.source ] : reading.datum.sources_for(reading.layer).select(&:connected?)
    [ sources.map(&:name).to_sentence, reading.confidence && t("app.fields.confidence.#{reading.confidence}") ].compact_blank.join(" · ")
  end

  # [origin, layer] pairs; one pair without a layer when both layers agree.
  def datum_origins(datum)
    datum.layered? ? datum.origins.map { |layer, origin| [ origin, layer ] } : [ [ datum.origin("global"), nil ] ]
  end

  def progress_label(subject)
    done, total = subject.progress
    t("app.fields.progress", done: done, total: total)
  end

  def progress_share(subject)
    done, total = subject.progress
    total.zero? ? 1 : (done.to_f / total).round(2)
  end

  private

  def reading_value(datum, value)
    case value
    when Numeric then number_with_precision(value, precision: datum.precision, strip_insignificant_zeros: true, delimiter: "")
    when Array
      return format("%.4f, %.4f", value[0], value[1]) if datum.key == "location"

      value.map { |option| option_label(datum, option) }.to_sentence
    when Hash then value.sort.map { |year, crop| "#{year}: #{crop}" }.join(" · ")
    when true, false then t("onboarding.values.boolean.#{value}")
    else datum.options.include?(value.to_s) ? option_label(datum, value) : value.to_s
    end
  end
end
