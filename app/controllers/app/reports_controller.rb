module App
  # Reports (menu section 5): the season summary, the attainable yield by
  # field (FAO GAEZ), and the downloads: the report as a PDF (Reports::Pdf),
  # and everything the farm holds as CSV or JSON (Reports::Export).
  class ReportsController < BaseController
    include FarmScreen

    def show
      @season = season
    end

    def harvest
    end

    def export
    end

    def download
      respond_to do |format|
        format.pdf do
          pdf = Reports::Pdf.new(farm: @farm, season: season, profile: Current.user.farmer_profile, view: helpers)
          send_data pdf.render, filename: pdf.filename, type: :pdf
        end
        format.json { send_data export.to_json, filename: export.filename("json"), type: :json }
        format.csv { send_data export.to_csv, filename: export.filename("csv"), type: "text/csv" }
      end
    end

    private

    def season = Weather::Season.for(@farm.main_field&.observation("nasa_power"))
    def export = Reports::Export.new(farm: @farm, season: season, profile: Current.user.farmer_profile, view: helpers)
  end
end
