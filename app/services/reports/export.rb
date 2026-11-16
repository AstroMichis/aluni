# frozen_string_literal: true

module Reports
  # The season report as data, with everything the farm holds behind it.
  # Read through the same helpers as the page and the PDF (ReportsHelper,
  # with the request's view context), so all three agree.
  #
  # CSV (a spreadsheet, in the person's language): one block per part of the
  # report, a blank row between blocks: the report, area by crop, weather,
  # field by field, each field's crops, the team, then every datum (one row
  # per value with its state, source and confidence).
  #
  # JSON (another tool): the same parts with stable keys and plain numbers
  # (hectares, shares from 0 to 1, months 1 to 12, slugs for checks and the
  # team), plus every field's seasons, sources and every datum.
  class Export
    COLUMNS = %w[subject datum state value source scale confidence].freeze

    def initialize(farm:, season:, profile:, view:)
      @farm = farm
      @season = season
      @profile = profile
      @view = view
    end

    def filename(extension) = "season-report-#{Date.current.iso8601}.#{extension}"

    def to_json(*)
      JSON.pretty_generate(
        "report" => { "title" => t("app.reports.show.headline"), "generated_on" => Date.current.iso8601, "locale" => I18n.locale.to_s,
                      "season" => @season.any? ? { "from" => @season.from.iso8601, "to" => @season.to.iso8601 } : nil,
                      "fields" => @farm.fields.size, "total_hectares" => round(@farm.total_area) },
        "area_by_crop" => @view.report_area_by_crop(@farm).map { |crop, area| { "crop" => crop, "hectares" => round(area) } },
        "weather" => weather_hash,
        "fields" => @farm.fields.map { |field| field_hash(field) },
        "team" => { "team" => @profile&.team, "team_size" => @profile&.team_size },
        "readings" => readings
      )
    end

    # RFC 4180: fields with a comma, quote or line break are quoted, quotes doubled.
    def to_csv
      blocks = [ report_block, crops_block, weather_block, fields_block, field_crops_block, team_block, data_block ].compact
      blocks.flat_map { |block| block + [ [] ] }.map { |line| line.map { |cell| quote(cell) }.join(",") }.join("\r\n") + "\r\n"
    end

    private

    # --- CSV blocks: a title row, then a header and rows -----------------------

    def report_block
      rows = [ [ t("app.reports.export.csv.generated"), Date.current.iso8601 ] ]
      rows << [ t("app.reports.export.csv.season"), "#{@season.from.iso8601} / #{@season.to.iso8601}" ] if @season.any?
      rows << [ t("app.reports.show.table.field"), @farm.fields.size ] << [ t("app.reports.show.table.area"), "#{round(@farm.total_area)} ha" ]
      [ [ t("app.reports.show.headline") ], *rows ]
    end

    def crops_block
      [ [ t("app.reports.show.crops_title") ], [ t("app.reports.show.table.crop"), t("app.reports.export.csv.hectares") ],
        *@view.report_area_by_crop(@farm).map { |crop, area| [ crop, round(area) ] } ]
    end

    def weather_block
      rows = @view.report_weather(@season)
      return if rows.empty?

      [ [ t("app.reports.show.weather_title") ], *rows.map { |label, value, unit| [ label, value, unit ] }, [ t("app.weather.show.regional") ] ]
    end

    def fields_block = [ [ t("app.reports.show.fields_title") ], @view.report_field_header, *@view.report_field_rows(@farm) ]

    def field_crops_block
      header = %w[field season role crop share hectares planting harvest source yield yield_unit price cost currency margin].map { |key| t("app.reports.export.csv.columns.#{key}") }
      rows = @farm.fields.flat_map do |field|
        field.record.field_crops.map do |c|
          [ @view.plot_name(field), c.season_year, @view.value_label("crop_role", c.role), c.crop_name, "#{(c.portion * 100).round}%",
            round(field.area_hectares * c.portion), c.planting_month, c.harvest_month, t("app.fields.crop_sources.#{c.source}"),
            c.yield_amount&.to_f, c.yield_unit && "#{c.yield_unit}/#{c.area_basis}", c.price&.to_f, c.cost&.to_f, c.currency, c.margin_per_ha&.round ]
        end
      end
      [ [ t("app.reports.export.csv.field_crops") ], header, *rows ]
    end

    def team_block = [ [ t("app.reports.show.team_title") ], [ @view.report_team(@profile) ] ]

    def data_block = [ [ t("app.reports.export.csv.data") ], COLUMNS, *readings.map { |row| row.values_at(*COLUMNS) } ]

    # --- JSON parts --------------------------------------------------------------

    def weather_hash
      return nil unless @season.any?

      totals = @season.totals
      { "source" => "NASA POWER", "scope" => "regional", "rain_mm" => totals[:rain]&.round, "mean_temp_c" => totals[:temp],
        "frost_days" => totals[:frost_days], "heat_days" => totals[:heat_days] }
    end

    def field_hash(field)
      record = field.record
      done, total = field.progress
      { "id" => field.key, "name" => field.name, "area" => record.area&.to_f, "area_unit" => record.area_unit, "hectares" => round(field.area_hectares),
        "latitude" => record.latitude&.to_f, "longitude" => record.longitude&.to_f,
        "current_season" => field.current_season, "crops" => field.current_crops.map { |c| crop_hash(field, c) },
        "plan" => field.plan_crops.map { |c| crop_hash(field, c) },
        "seasons" => record.field_crops.map { |c| crop_hash(field, c).merge("season_year" => c.season_year, "role" => c.role) },
        "rotation_checks" => Crops::RotationCheck.new(field.seasons).findings.map { |f| { "kind" => f.kind, "seasons" => f.years } },
        "data_ready" => { "done" => done, "total" => total },
        "sources" => field.observations.to_h { |o| [ o.source, { "status" => o.status, "fetched_at" => o.fetched_at&.iso8601 } ] } }
    end

    def crop_hash(field, crop)
      { "crop" => crop.crop_name, "scientific_name" => crop.scientific_name, "share" => crop.portion, "hectares" => round(field.area_hectares * crop.portion),
        "cells" => crop.map_cells, "planting_month" => crop.planting_month, "harvest_month" => crop.harvest_month, "source" => crop.source,
        "harvest" => crop.harvest? ? harvest_hash(crop) : nil }
    end

    def harvest_hash(crop)
      { "yield" => crop.yield_amount.to_f, "yield_unit" => crop.yield_unit, "area_basis" => crop.area_basis, "price" => crop.price&.to_f,
        "cost" => crop.cost&.to_f, "currency" => crop.currency, "margin_per_ha" => crop.margin_per_ha&.round }
    end

    # Every datum of the farm and each field, with its state, source and confidence.
    def readings
      @readings ||= [ @farm, *@farm.fields ].flat_map do |subject|
        subject.readings.map do |r|
          { "subject" => subject.key, "datum" => r.datum.key, "state" => r.state.to_s, "value" => r.known? ? flat(r.values) : nil,
            "source" => r.source&.name, "scale" => r.known? ? r.scale : nil, "confidence" => r.known? ? r.confidence : nil }
        end
      end
    end

    def flat(values)
      values.size == 1 ? Array(values.values.first).join("; ") : values.map { |k, v| "#{k}=#{v}" }.join("; ")
    end

    def round(value) = value.to_f.round(2)

    def quote(cell)
      text = cell.to_s
      text.match?(/[",\r\n]/) ? %("#{text.gsub('"', '""')}") : text
    end

    def t(key, **options) = @view.t(key, **options)
  end
end
