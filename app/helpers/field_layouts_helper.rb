# frozen_string_literal: true

# The field map (a season's crops on a 10x10 grid of the field) and the
# "Plan the planting" form: which crop each cell carries, each crop's area in
# the field's unit, the mix in words, and the rows the planner starts from.
# A crop's slot (0 to 5) is its place in the season, largest first; the map
# styles colour and texture by slot (components/crop-layout.css).
module FieldLayoutsHelper
  # Cell index => slot of the crop on it, nil when nothing grows there.
  def layout_slots(crops)
    slots = Array.new(FieldCrop::GRID)
    crops.each_with_index { |crop, i| crop.map_cells.each { |cell| slots[cell] = i } }
    slots
  end

  # A part of the field in its own unit ("1 ha", "2.5 acres"), or a percent
  # when the field has no area.
  def portion_area(field, portion)
    area = field.record.area
    return number_to_percentage(portion * 100, precision: 0) if area.blank?

    t("app.fields.units.#{field.record.area_unit}", value: number_with_precision(area.to_f * portion, precision: 2, strip_insignificant_zeros: true))
  end

  # "Corn 1 ha · Beans 1 ha" for a split season, the crop's name otherwise.
  def crop_mix(field, crops = field.current_crops)
    return t("app.fields.index.no_crop") if crops.empty?
    return crop_name(crops.first) if crops.size == 1 && crops.first.whole_field?

    crops.map { |crop| "#{crop_name(crop)} #{portion_area(field, crop.portion)}" }.join(" · ")
  end

  # A piece of the field in words: "Corn · 16.2 ha" (fallow: "Not planted").
  def zone_label(field, zone)
    crop = zone.current_crop ? crop_name(zone.current_crop) : t("app.field_layouts.map.empty_label")
    "#{crop} · #{portion_area(field, zone.share)}"
  end

  # The pieces worth comparing: every zone that carries a crop this season.
  def planted_zones(field) = field.zones.reject(&:fallow?)

  # The planner's rows for a season: one per crop, or one empty row.
  def layout_form_rows(field, year)
    crops = field.season_crops(year)
    return [ {} ] if crops.empty?

    crops.map { |crop| layout_row(field, crop) }
  end

  # The season before, for "Copy last season" and "Swap": name, share, cells.
  def layout_previous(field, year)
    field.season_crops(year - 1).map { |crop| { crop: crop.crop_name, share: crop.portion, cells: crop.map_cells } }
  end

  def layout_row(field, crop)
    area = field.record.area
    { crop: crop.crop_name, share: crop.portion, cells: crop.map_cells,
      amount: plain_number(area.present? ? (area.to_f * crop.portion).round(2) : (crop.portion * 100).round(1)),
      planting_month: crop.planting_month, harvest_month: crop.harvest_month }
  end

  # The amount inputs work in the field's unit, or in percent without an area.
  def layout_unit(field)
    field.record.area.present? ? t("app.field_layouts.units.#{field.record.area_unit}") : "%"
  end

  # 1.0 reads "1" in a number input; decimals stay with a dot, as inputs want.
  def plain_number(value) = value == value.to_i ? value.to_i : value

  def layout_total(field) = field.record.area.present? ? field.record.area.to_f : 100.0
end
