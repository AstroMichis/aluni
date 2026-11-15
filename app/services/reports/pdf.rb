# frozen_string_literal: true

require "prawn"
require "prawn/table"

module Reports
  # The season report as a PDF (Prawn): the same content as the report page,
  # read through the same helpers (ReportsHelper) with the request's view
  # context, so the language and the numbers match what the person sees. A
  # white page in the brand's colours, a header, area by crop, the season's
  # weather, a row per field, the team, and page numbers.
  #
  # Prawn's built-in Helvetica covers Western European text (Windows-1252);
  # anything outside it prints as "?" rather than failing the download.
  class Pdf
    INK = "173D2D"
    MUTED = "566659"
    ACCENT = "8A7442"
    RULE = "D4CAB2"
    ZEBRA = "F6F2E8"

    Prawn::Fonts::AFM.hide_m17n_warning = true

    def initialize(farm:, season:, profile:, view:)
      @farm = farm
      @season = season
      @profile = profile
      @view = view
    end

    def filename = "season-report-#{Date.current.iso8601}.pdf"

    def render
      pdf = Prawn::Document.new(page_size: "A4", margin: [ 48, 44, 56, 44 ], info: { Title: t("app.reports.show.headline"), Creator: t("app_name") })
      pdf.font("Helvetica", size: 10)
      pdf.fill_color(INK)
      header(pdf)
      crops(pdf)
      weather(pdf)
      fields(pdf)
      team(pdf)
      footer(pdf)
      pdf.render
    end

    private

    def header(pdf)
      pdf.text safe(t("app_name")), size: 11, style: :bold, color: ACCENT
      pdf.text safe(t("app.reports.show.headline")), size: 24, style: :bold
      if @season.any?
        pdf.text safe(t("app.reports.show.eyebrow", from: @view.l(@season.from, format: :long), to: @view.l(@season.to, format: :long))), color: MUTED
      end
      pdf.text safe(t("app.reports.show.lede", count: @farm.fields.size, area: @view.hectares(@farm.total_area))), color: MUTED
      pdf.move_down 6
      pdf.stroke_color(RULE)
      pdf.stroke_horizontal_rule
    end

    def crops(pdf)
      section(pdf, "app.reports.show.crops_title")
      rows = @view.report_area_by_crop(@farm)
      return note(pdf, t("app.crops.show.none")) if rows.empty?

      table(pdf, rows.map { |crop, area| [ crop, @view.hectares(area) ] }, widths: [ 260, 120 ])
    end

    def weather(pdf)
      rows = @view.report_weather(@season)
      return if rows.empty?

      section(pdf, "app.reports.show.weather_title")
      table(pdf, rows.map { |label, value, unit| [ label, [ value, unit ].compact.join(" ") ] }, widths: [ 260, 120 ])
      note(pdf, t("app.weather.show.regional"))
    end

    def fields(pdf)
      section(pdf, "app.reports.show.fields_title")
      table(pdf, [ @view.report_field_header ] + @view.report_field_rows(@farm), header: true)
    end

    def team(pdf)
      section(pdf, "app.reports.show.team_title")
      pdf.text safe(@view.report_team(@profile))
    end

    def footer(pdf)
      text = safe(t("app.reports.pdf.footer", date: @view.l(Date.current, format: :long), app_name: t("app_name"), page: "<page>", total: "<total>"))
      pdf.number_pages text, at: [ pdf.bounds.left, -18 ], width: pdf.bounds.width, size: 8, color: MUTED
    end

    def section(pdf, key)
      pdf.move_down 16
      pdf.text safe(t(key)), size: 13, style: :bold
      pdf.move_down 6
    end

    def note(pdf, text)
      pdf.move_down 4
      pdf.text safe(text), size: 8, color: MUTED
    end

    def table(pdf, rows, widths: nil, header: false)
      data = rows.map { |row| row.map { |cell| safe(cell) } }
      options = { width: widths ? widths.sum : pdf.bounds.width, header: header, row_colors: [ "FFFFFF", ZEBRA ],
                  cell_style: { size: 9, padding: [ 5, 6 ], border_width: 0.5, border_color: RULE, text_color: INK } }
      options[:column_widths] = widths if widths
      pdf.table(data, options) do |table|
        next unless header

        table.row(0).font_style = :bold
        table.row(0).background_color = INK
        table.row(0).text_color = "FFFFFF"
      end
    end

    def t(key, **options) = @view.t(key, **options)

    def safe(text) = text.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
  end
end
