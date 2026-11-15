# frozen_string_literal: true

# The shell shared by the menu sections: their tabs (shared/_screen_bar).
module ScreenHelper
  SECTION_TABS = {
    fields:  { fields: :menu_fields_path, farm: :farm_menu_fields_path, sources: :sources_menu_fields_path },
    crops:   { now: :menu_crops_path, rotation: :rotation_menu_crops_path, calendar: :calendar_menu_crops_path },
    weather: { season: :menu_weather_path, alerts: :alerts_menu_weather_path },
    staff:   { team: :menu_staff_path, tasks: :tasks_menu_staff_path, roles: :roles_menu_staff_path },
    reports: { season: :menu_reports_path, harvest: :harvest_menu_reports_path, export: :export_menu_reports_path }
  }.freeze

  def section_tabs(section)
    SECTION_TABS.fetch(section).map { |key, route| [ t("#{section}.tabs.#{key}"), public_send(route) ] }
  end
end
