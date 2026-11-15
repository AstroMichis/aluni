require "rails_helper"

RSpec.describe "Report downloads", type: :request do
  let(:user) { create(:user, display_name: "Ana") }
  let!(:field) { create_farm_for(user) }

  before { sign_in_as(user) }

  # Prawn writes uncompressed text as hex strings in Windows-1252, split by
  # kerning inside each TJ array: joined back, one shown string per array.
  def pdf_text
    response.body.b.scan(/\[([^\]]*)\]\s*TJ|(<[0-9a-fA-F]+>)\s*Tj/).map do |array, single|
      (array || single).scan(/<([0-9a-fA-F]+)>/).map { |(hex)| [ hex ].pack("H*") }.join.force_encoding("Windows-1252").encode("UTF-8")
    end.join(" ")
  end

  it "offers the three downloads on the report itself" do
    get app_reports_path(locale: "en"), headers: native_headers

    %w[pdf csv json].each do |format|
      expect(response.body).to include(%(href="/en/app/reports/download.#{format}"))
    end
  end

  it "downloads the season report as a PDF, in the person's language" do
    field.update!(area: 2)
    Fields::SeasonLayoutService.call(user: user, field: field.id, year: Date.current.year,
                                     crops: [ { crop: "Corn", share: 0.5 }, { crop: "Beans", share: 0.5 } ])

    get download_app_reports_path(format: :pdf, locale: "es"), headers: native_headers

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(response.headers["Content-Disposition"]).to include("attachment").and include("season-report-#{Date.current.iso8601}.pdf")
    expect(response.body).to start_with("%PDF")
    text = pdf_text
    expect(text).to include(I18n.t("app.reports.show.headline", locale: :es)).and include("North field")
    expect(text).to include("Corn").and include("Beans").and include(I18n.t("app.reports.show.table.plan", locale: :es))
  end

  context "with the field split between two crops" do
    before do
      field.update!(area: 2)
      Fields::SeasonLayoutService.call(user: user, field: field.id, year: Date.current.year,
                                       crops: [ { crop: "Corn", share: 0.6 }, { crop: "Beans", share: 0.4 } ])
    end

    it "exports the report as a spreadsheet, block by block, in the person's language" do
      get download_app_reports_path(format: :csv, locale: "es"), headers: native_headers

      expect(response.media_type).to eq("text/csv")
      csv = response.body
      t = ->(key, **opts) { I18n.t(key, locale: :es, **opts) }
      [ "app.reports.show.headline", "app.reports.show.crops_title", "app.reports.show.weather_title", "app.reports.show.fields_title",
        "app.reports.export.csv.field_crops", "app.reports.show.team_title", "app.reports.export.csv.data" ].each do |key|
        title = t.(key).include?(",") ? %("#{t.(key)}") : t.(key) # a comma is quoted (RFC 4180)
        expect(csv).to include("\r\n#{title}\r\n").or start_with("#{title}\r\n")
      end
      expect(csv).to include("Corn,1.2\r\n").and include("Beans,0.8\r\n")                              # area by crop
      expect(csv).to include("North field,#{Date.current.year},#{t.("onboarding.values.crop_role.main")},Corn,60%,1.2,4,10,") # crops by field
      expect(csv).to include("#{field.id},slope,auto,1.2,USGS 3DEP,parcel,high")                          # every datum
    end

    it "exports the same report for another tool, with plain numbers and stable keys" do
      get download_app_reports_path(format: :json, locale: "en"), headers: native_headers

      expect(response.media_type).to eq("application/json")
      data = response.parsed_body
      expect(data["report"]).to include("title" => I18n.t("app.reports.show.headline"), "fields" => 1, "total_hectares" => 2.0)
      expect(data["area_by_crop"]).to eq([ { "crop" => "Corn", "hectares" => 1.2 }, { "crop" => "Beans", "hectares" => 0.8 } ])
      expect(data["weather"]).to include("source" => "NASA POWER", "rain_mm" => a_kind_of(Integer))
      field_data = data["fields"].sole
      expect(field_data["crops"].map { |c| c.slice("crop", "share", "hectares") })
        .to eq([ { "crop" => "Corn", "share" => 0.6, "hectares" => 1.2 }, { "crop" => "Beans", "share" => 0.4, "hectares" => 0.8 } ])
      expect(field_data).to include("data_ready" => include("done", "total"), "sources" => include("nasa_power" => include("status" => "ok")))
      expect(data["readings"]).to include(include("subject" => field.id.to_s, "datum" => "slope", "source" => "USGS 3DEP"))
    end
  end
end
