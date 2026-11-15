module App
  # Reports (menu section 5): the season summary, the attainable yield by
  # field (FAO GAEZ), and an export of everything the farm holds.
  class ReportsController < BaseController
    include FarmScreen

    def show
      @season = Weather::Season.for(@farm.main_field&.observation("nasa_power"))
    end

    def harvest
    end

    def export
    end

    def download
      report = Reports::Export.new(@farm)
      respond_to do |format|
        format.json { send_data report.to_json, filename: report.filename("json"), type: :json }
        format.csv { send_data report.to_csv, filename: report.filename("csv"), type: "text/csv" }
      end
    end
  end
end
