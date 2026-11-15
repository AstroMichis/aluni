# Reports (section 5): the season summary, the harvest by field, and an
# export of everything the farm holds (JSON or CSV).
class ReportsController < ApplicationController
  include FarmPreview

  def show
    @season = Weather::Season.load
  end

  def harvest
  end

  def export
  end

  def download
    report = Reports::Export.new(@farm, profile: @profile)
    respond_to do |format|
      format.json { send_data report.to_json, filename: report.filename("json"), type: :json }
      format.csv { send_data report.to_csv, filename: report.filename("csv"), type: "text/csv" }
    end
  end
end
