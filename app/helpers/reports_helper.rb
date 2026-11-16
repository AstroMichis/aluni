# frozen_string_literal: true

# The season report's content, once, for the page (app/reports/show) and the
# PDF (Reports::Pdf, which draws it with this same view context): the area
# by crop, the weather of the season, a row per field and the team.
module ReportsHelper
  REPORT_FORMATS = %w[pdf csv json].freeze

  # [[crop name, hectares]], largest first; a split field counts each crop's part.
  def report_area_by_crop(farm)
    farm.fields.flat_map { |field| field.current_crops.map { |crop| [ crop_name(crop), field.area_hectares * crop.portion ] } }
        .group_by(&:first).transform_values { |pairs| pairs.sum(&:last) }.sort_by { |_, area| -area }
  end

  # [[label, value, unit]] for the season's weather, or [] without one.
  def report_weather(season)
    return [] unless season.any?

    totals = season.totals
    [ [ t("app.weather.show.kpis.rain"), chart_number(totals[:rain], 0), "mm" ], [ t("app.weather.show.kpis.temp"), chart_number(totals[:temp]), "°C" ],
      [ t("app.weather.show.kpis.frost_days"), totals[:frost_days].to_s, nil ], [ t("app.weather.show.kpis.heat_days"), totals[:heat_days].to_s, nil ] ]
  end

  # The field table's header and one row of text per field.
  def report_field_header = %w[field crop area plan flags ready].map { |key| t("app.reports.show.table.#{key}") }

  def report_field_rows(farm)
    farm.fields.map do |field|
      findings = Crops::RotationCheck.new(field.seasons).findings
      [ plot_name(field), crop_mix(field), field_area(field),
        field.plan_crops.any? ? crop_mix(field, field.plan_crops) : t("app.reports.show.table.no_plan"),
        findings.any? ? findings.map { |f| t("app.crops.rotation.findings.#{f.kind}.label") }.uniq.to_sentence : t("app.reports.show.table.no_flags"),
        progress_label(field) ]
    end
  end

  def report_team(profile)
    team = profile && !profile.team_unknown? ? value_label("team", profile.team) : t("app.fields.states.unanswered")
    profile&.team_size ? "#{team} · #{t('app.reports.show.team_size', count: profile.team_size)}" : team
  end

  # The report's three downloads, PDF first.
  # "11.2 t/ha" or "180 bu/ac": a recorded yield in the farmer's own units.
  def harvest_yield(crop)
    t("app.reports.harvest.own.yield", value: number_with_precision(crop.yield_amount, precision: 2, strip_insignificant_zeros: true),
                                       unit: t("app.harvests.edit.units_short.#{crop.yield_unit}"), basis: crop.area_basis)
  end

  # A per-hectare money figure with its currency code.
  def harvest_money(value, currency) = "#{number_with_delimiter(value.round)} #{currency}"

  def report_download_links(**options)
    safe_join(REPORT_FORMATS.map do |format|
      link_to format.upcase, download_app_reports_path(format: format), data: { turbo: false }, download: "",
                                                                       aria: { label: t("app.reports.downloads.#{format}") }, **options
    end, " ")
  end
end
