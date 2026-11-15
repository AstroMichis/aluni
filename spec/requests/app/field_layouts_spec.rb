require "rails_helper"

RSpec.describe "Plan the planting", type: :request do
  let(:user) { create(:user, display_name: "Ana") }
  let!(:field) { create_farm_for(user) }
  let(:year) { Date.current.year }

  before { sign_in_as(user) }

  def split_field
    field.update!(area: 2)
    patch app_field_layout_path(field, locale: "en", year: year), headers: native_headers,
          params: { crops: [ { crop: "Corn", amount: "1", cells: "" }, { crop: "Beans", amount: "1", cells: "" } ] }
  end

  it "renders the season's crops, the map and every season" do
    get edit_app_field_layout_path(field, locale: "en"), headers: native_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="crop-layout"').and include('role="grid"').and include('name="crops[][amount]"')
    expect(response.body).to include(I18n.t("app.field_layouts.edit.headline", year: year)).and include('value="Corn"')
    expect(response.body).to include(%(href="/en/app/fields/#{field.id}/layout/edit?year=#{year + 1}"))
  end

  it "splits a 2 ha field into 1 ha of corn and 1 ha of beans and shows it everywhere" do
    split_field

    expect(response).to redirect_to(app_field_path(field, locale: "en"))
    expect(field.field_crops.where(season_year: year).pluck(:crop_name, :share).sort).to eq([ [ "Beans", 0.5 ], [ "Corn", 0.5 ] ])

    get app_field_path(field, locale: "en"), headers: native_headers
    expect(response.body).to include("Corn 1 ha · Beans 1 ha").and include("crop-map--editable")

    get app_crops_path(locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.crops.show.part", area: "1 ha", total: "2 ha")).and include("Beans")

    get calendar_app_crops_path(locale: "en"), headers: native_headers
    expect(response.body).to include("Corn · 1 ha").and include("Beans · 1 ha")

    get harvest_app_reports_path(locale: "en"), headers: native_headers
    expect(response.body).to include("Corn <small>").or include("Corn · 1 ha")

    get download_app_reports_path(format: :json, locale: "en"), headers: native_headers
    expect(response.parsed_body.dig("fields", 0, "crops").pluck("share")).to include(0.5)
  end

  it "compares rotations per piece of the field and plans one piece" do
    split_field

    get app_field_rotation_path(field, locale: "en"), headers: native_headers
    expect(response.body).to include('class="zone-picker"').and include("Corn · 1 ha").and include("Beans · 1 ha")

    patch plan_app_crops_path(locale: "en"), headers: native_headers, params: { field: field.id, zone: 1, crop: "triticum-aestivum" }
    plan = field.field_crops.where(season_year: year + 1).sole
    expect(plan).to have_attributes(scientific_name: "Triticum aestivum", share: 0.5)
  end

  it "edits a split season in the planner, not in the field form" do
    split_field

    get edit_app_field_path(field, locale: "en"), headers: native_headers
    expect(response.body).not_to include('name="values[current_crop]"')
    expect(response.body).to include(%(href="/en/app/fields/#{field.id}/layout/edit?year=#{year}"))
  end

  it "says why a planting cannot be saved" do
    patch app_field_layout_path(field, locale: "en", year: year), headers: native_headers,
          params: { crops: [ { crop: "Corn", amount: "30" }, { crop: "Beans", amount: "30" } ] }

    expect(response).to redirect_to(edit_app_field_layout_path(field, locale: "en", year: year))
    follow_redirect!(headers: native_headers)
    expect(response.body).to include(I18n.t("app.field_layouts.update.errors.over"))
  end
end
