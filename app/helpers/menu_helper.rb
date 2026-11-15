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
    fields:  %i[add list sources],
    crops:   %i[current rotation calendar],
    weather: %i[forecast moisture alerts],
    staff:   %i[team],
    reports: %i[season yield export]
  }.freeze

  # Where each option leads (route helper names); an option missing here shows "Coming soon".
  OPTION_PATHS = {
    fields:  { add: :new_app_field_path, list: :app_fields_path, sources: :sources_app_fields_path },
    crops:   { current: :app_crops_path, rotation: :rotation_app_crops_path, calendar: :calendar_app_crops_path },
    weather: { forecast: :app_weather_path, moisture: :app_weather_path, alerts: :alerts_app_weather_path },
    staff:   { team: :app_team_path },
    reports: { season: :app_reports_path, yield: :harvest_app_reports_path, export: :export_app_reports_path }
  }.freeze

  # Each section's first screen: the hub, the switcher and the dial's Enter go here.
  SECTION_PATHS = {
    fields: :app_fields_path, crops: :app_crops_path, weather: :app_weather_path,
    staff: :app_team_path, reports: :app_reports_path
  }.freeze

  # Which section a screen belongs to, by controller.
  CONTROLLER_SECTIONS = {
    "fields" => :fields, "farms" => :fields, "crops" => :crops, "rotations" => :crops,
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
