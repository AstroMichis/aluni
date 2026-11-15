# frozen_string_literal: true

# The shell shared by the menu sections: their tabs (shared/_screen_bar).
module ScreenHelper
  SECTION_TABS = {
    fields:  { fields: :app_fields_path, farm: :app_farm_path, sources: :sources_app_fields_path },
    crops:   { now: :app_crops_path, rotation: :rotation_app_crops_path, calendar: :calendar_app_crops_path },
    weather: { season: :app_weather_path, alerts: :alerts_app_weather_path },
    reports: { season: :app_reports_path, harvest: :harvest_app_reports_path, export: :export_app_reports_path }
  }.freeze

  def section_tabs(section)
    SECTION_TABS.fetch(section).map { |key, route| [ t("app.#{section}.tabs.#{key}"), public_send(route) ] }
  end
end
