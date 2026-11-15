# frozen_string_literal: true

# Presentation for My fields: reading values, crop names and glyphs, and the
# plant layout of the illustrated field (fields/_plot).
module FieldsHelper
  GROUP_GLYPHS = {
    "place" => "map", "climate" => "weather", "water" => "moisture", "resources" => "tasks",
    "market" => "yield", "goals" => "tips", "profile" => "team", "plot" => "fields",
    "crop" => "crops", "soil" => "soil", "terrain" => "terrain", "vegetation" => "imagery", "harvest" => "yield", "notes" => "notes"
  }.freeze

  # Classification axes that read an asked datum's labels; size has its own.
  CLASSIFICATION_DATA = { "water" => "water_access", "inputs" => "fertilizer_level", "goal" => "goals", "tech" => "tech_level" }.freeze

  # The illustrated field is a wedge (like the menu dial's) seen in
  # perspective: rows narrow towards the bottom edge.
  PLOT_ROWS = [ [ 52, 5, 26, 174 ], [ 78, 4, 40, 160 ], [ 104, 3, 54, 146 ] ].freeze # y, plants, x from, x to

  def plot_plants
    PLOT_ROWS.each_with_index.flat_map do |(y, count, from, to), row|
      Array.new(count) { |i| { x: from + ((to - from) * (i + 0.5) / count), y: y, delay: (row * 4) + i } }
    end
  end

  # The plant shape of the crop's kind (config/crops.yml); nil for a resting field.
  def crop_shape(crop) = Crops::Catalog.shape(crop)
  def crop_name(crop) = t("fields.options.current_crop.#{crop}", default: crop.to_s.humanize)
  def group_glyph(group) = GROUP_GLYPHS.fetch(group)
  def field_name(field) = field.name.presence || t("fields.sample.#{field.key}", default: t("fields.untitled"))
  def subject_name(subject) = subject.is_a?(Fields::Farm::Field) ? field_name(subject) : t("fields.farm.headline")

  # The action a card offers for its state (nil: nothing to do yet).
  def reading_action(reading)
    case reading.state
    when :unanswered, :gap then "answer"
    when :answered then "change"
    when :to_confirm, :auto, :confirmed, :corrected then "correct"
    end
  end

  # "7 of 10 ready" and the share for the meter.
  def progress_label(subject)
    done, total = subject.progress
    t("fields.progress", done: done, total: total)
  end

  def progress_share(subject)
    done, total = subject.progress
    total.zero? ? 1 : (done.to_f / total).round(2)
  end
  def hectares(value) = t("fields.units.hectares", value: number_with_precision(value, precision: 1, strip_insignificant_zeros: true))

  # What a card shows: the value, or what is missing.
  def reading_text(reading)
    return t("fields.states.#{reading.state}") unless reading.known?

    datum = reading.datum
    values = reading.values.transform_values { |value| reading_value(datum, value) }
    t("fields.data.#{datum.key}.value", **values.symbolize_keys, default: values.values.join(", "))
  end

  # Where it comes from: the source and its confidence (nothing for what the person said).
  def reading_origin(reading)
    return t("fields.origin.corrected") if reading.state == :corrected
    return if reading.source.nil? && reading.known?

    sources = reading.source ? [ reading.source ] : reading.datum.sources_for(reading.layer)
    [ sources.map(&:name).to_sentence, reading.confidence && t("fields.confidence.#{reading.confidence}") ].compact.join(" · ")
  end

  # [origin, layer] pairs; one pair without a layer when both layers agree.
  def datum_origins(datum)
    datum.layered? ? datum.origins.map { |layer, origin| [ origin, layer ] } : [ [ datum.origin("global"), nil ] ]
  end

  def classification_value(axis, value)
    key = CLASSIFICATION_DATA[axis]
    key ? t("fields.options.#{key}.#{value}") : t("fields.classification.#{axis}.#{value}")
  end

  def datum_label(datum) = t("fields.data.#{datum.key}.label")
  def option_label(datum, option)
    datum.months ? t("date.month_names")[option.to_i] : t("fields.options.#{datum.key}.#{option}")
  end

  private

  def reading_value(datum, value)
    case value
    when Numeric then number_with_precision(value, precision: datum.precision, strip_insignificant_zeros: true, delimiter: "")
    when Array then value.map { |option| option_label(datum, option) }.to_sentence
    when Hash then value.sort.map { |_year, crop| crop_name(crop.to_s.parameterize(separator: "_")) }.join(" → ")
    else datum.options.include?(value.to_s) ? option_label(datum, value) : value.to_s
    end
  end
end
