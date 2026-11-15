# frozen_string_literal: true

# The main menu dial: its sections, their options (shown under the wheel for
# the selected section), where each section starts, which section a screen
# belongs to (the section switcher and the way back to the dial), and the SVG
# geometry. Copy lives in app.home.show.*; each section key is also its tone
# (menu.css).
#
# The dial is drawn in a viewBox centred on 0,0. Every wedge is the same path
# at 12 o'clock, rotated into place, so its texture, label and selected lift
# all work in one local frame where "outwards" is straight up.
module MenuHelper
  SECTIONS = {
    fields:  %i[planting list add],
    crops:   %i[current rotation calendar],
    weather: %i[forecast moisture alerts],
    staff:   %i[team],
    reports: %i[season yield export]
  }.freeze

  # Where each option leads (route helper names); an option missing here shows "Coming soon".
  OPTION_PATHS = {
    fields:  { planting: :planting_entry_path, list: :fields_entry_path, add: :new_app_field_path },
    crops:   { current: :app_crops_path, rotation: :rotation_app_crops_path, calendar: :calendar_app_crops_path },
    weather: { forecast: :app_weather_path, moisture: :app_weather_path, alerts: :alerts_app_weather_path },
    staff:   { team: :app_team_path },
    reports: { season: :app_reports_path, yield: :harvest_app_reports_path, export: :export_app_reports_path }
  }.freeze

  # Each section's first screen: the hub, the switcher and the dial's Enter go here.
  SECTION_PATHS = {
    fields: :fields_entry_path, crops: :app_crops_path, weather: :app_weather_path,
    staff: :app_team_path, reports: :app_reports_path
  }.freeze

  # Which section a screen belongs to, by controller.
  CONTROLLER_SECTIONS = {
    "fields" => :fields, "farms" => :fields, "field_layouts" => :fields, "rotations" => :fields, "crops" => :crops,
    "weather" => :weather, "team" => :staff, "reports" => :reports
  }.freeze

  INNER = 60
  OUTER = 95
  GAP = 3.5 # degrees between wedges

  def menu_sections = SECTIONS

  def menu_option_path(section, option)
    name = OPTION_PATHS.dig(section, option)
    public_send(name) if name
  end

  def menu_section_path(section) = public_send(SECTION_PATHS.fetch(section))

  def current_menu_section = CONTROLLER_SECTIONS[controller_name]

  # My fields: the field's own workspace when the farm has only one.
  def fields_entry_path
    fields = @farm&.fields
    fields&.one? ? app_field_path(fields.first.key) : app_fields_path
  end

  # Plan the planting: the main field's page, whose planner is open, or a first field.
  def planting_entry_path
    field = @farm&.main_field
    field ? app_field_path(field.key) : new_app_field_path
  end

  # Up to three things to do next, each one tap from the home: confirm what
  # the sources propose, fill the essentials still missing, plan next season.
  # Built from what the farm already knows (Fields::Farm); no outside call.
  def home_shortcuts(farm, limit: 3)
    return [ [ :add, t("app.home.show.shortcuts.add"), new_app_field_path ] ] if farm.fields.empty?

    next_year = Date.current.year + 1
    list = farm.fields.flat_map do |field|
      name = plot_name(field)
      suggestions = field.suggestions_count
      [ ([ :suggestions, t("app.home.show.shortcuts.suggestions", count: suggestions, name: name), app_field_path(field.key, anchor: "suggestions") ] if suggestions.positive?),
        ([ :todo, t("app.home.show.shortcuts.todo", count: field.todo.size, name: name), edit_focus_path(edit_app_field_path(field.key), field.todo.first.datum.key) ] if field.todo.any?),
        ([ :plan, t("app.home.show.shortcuts.plan", year: next_year, name: name), edit_app_field_layout_path(field.key, year: next_year) ] if !field.empty? && field.plan_crops.empty?) ]
    end
    list << [ :todo, t("app.home.show.shortcuts.profile", count: farm.todo.size), edit_focus_path(edit_app_farm_path, farm.todo.first.datum.key) ] if farm.todo.any?
    list.compact.sort_by { |kind, _, _| %i[suggestions todo plan].index(kind) }.first(limit)
  end

  # Things waiting on the farmer, per section, for the dot on its wedge: the
  # values the sources propose and the essentials still missing. Same data as
  # home_shortcuts; sections with nothing waiting are left out.
  def menu_badges(farm)
    return {} unless farm
    fields = farm.fields.sum { |field| field.suggestions_count + field.todo.size } + farm.todo.size
    { fields: fields }.select { |_, count| count.positive? }
  end

  # The dial, turned to the section this screen belongs to.
  def back_to_menu_path = app_root_path(section: current_menu_section)

  # The section the dial opens on: ?section=weather, else the first.
  def dial_index(param) = SECTIONS.keys.index { |key| key.to_s == param.to_s } || 0

  def dial_step = 360.0 / SECTIONS.size

  # "01 / 05" for the section at index i.
  def dial_kicker(index)
    t("app.home.show.kicker", number: format("%02d", index + 1), total: format("%02d", SECTIONS.size))
  end

  # An annular wedge centred on 12 o'clock (each spans well under 180 degrees,
  # so both arcs use the small-arc flag).
  def dial_wedge_path
    half = (dial_step - GAP) / 2
    "M#{dial_point(OUTER, -90 - half)} A#{OUTER} #{OUTER} 0 0 1 #{dial_point(OUTER, -90 + half)} " \
      "L#{dial_point(INNER, -90 + half)} A#{INNER} #{INNER} 0 0 0 #{dial_point(INNER, -90 - half)} Z"
  end

  # The tick ring as one path: a mark every 6 degrees, longer every 30.
  def dial_ticks_path(long:)
    (0...60).select { |i| (i % 5).zero? == long }.map do |i|
      "M#{dial_point(long ? 96.5 : 97.5, i * 6)} L#{dial_point(99.5, i * 6)}"
    end.join(" ")
  end

  def dial_point(radius, degrees)
    rad = degrees * Math::PI / 180
    format("%.2f %.2f", radius * Math.cos(rad), radius * Math.sin(rad))
  end
end
