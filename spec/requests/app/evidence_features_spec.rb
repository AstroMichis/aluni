require "rails_helper"

# What docs/proposal's hindcast changed in the app: when to scout, soil loss in
# tonnes, the farmer's own yields and margin, the verdicts beside the advice.
RSpec.describe "Evidence-backed features", type: :request do
  let(:user) { create(:user) }
  let!(:field) { create_farm_for(user) }
  let(:crop) { field.field_crops.find_by(role: :main, season_year: field.field_crops.maximum(:season_year)) }

  before { sign_in_as(user) }

  it "shows growing degree days, when to scout and the data verdict on the weather page" do
    get app_weather_path(locale: "en"), headers: native_headers

    expect(response.body).to include(I18n.t("app.weather.show.kpis.gdd")).and include(I18n.t("app.weather.scout.title"))
    expect(response.body).to include(I18n.t("app.weather.scout.armyworm.label")).and include("gray leaf spot")
    expect(response.body).to include('href="/en/evidence#study-v1"').and include('href="/en/evidence#study-v5"')
  end

  it "lets the farmer choose scout alerts" do
    patch alerts_app_weather_path(locale: "en"), params: { alerts: [ "", "scout" ] }, headers: native_headers
    expect(user.farmer_profile.reload.notification_preferences["weather"]).to eq(%w[scout])

    get alerts_app_weather_path(locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.weather.alerts.kinds.scout.label"))
  end

  it "puts the soil loss in tonnes and the rotation evidence on the rotation tab" do
    create(:field_observation, field: field, source: "gpm_imerg", payload: Weather::RainExtremes.summarize(
      (Date.new(2015, 1, 1)..Date.new(2024, 12, 31)).to_h { |d| [ d.strftime("%Y%m%d"), (d.day % 4).zero? ? 12.0 : 0.0 ] }
    ))

    get app_field_rotation_path(field, locale: "en"), headers: native_headers

    expect(response.body).to include("t of soil a hectare a year").and include("Residue values are assumed")
    expect(response.body).to include('href="/en/evidence#study-v4"').and include('href="/en/evidence#study-v6"')
    expect(response.body).to include("record the yield and price")
  end

  it "records a harvest, lists it before the GAEZ reference, and exports it" do
    get harvest_app_reports_path(locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.reports.harvest.own.record")).and include(I18n.t("app.reports.harvest.reference.title"))
    expect(response.body).to include('href="/en/evidence#study-v3"')

    get edit_app_field_harvest_path(field, crop, locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.harvests.edit.price_hint"))

    patch app_field_harvest_path(field, crop, locale: "en"), headers: native_headers, params: {
      harvest: { yield_amount: "11,5", yield_unit: "t", area_basis: "ha", price: "180", cost: "1200", currency: "USD" }
    }
    expect(response).to redirect_to(harvest_app_reports_path(locale: "en"))
    expect(crop.reload.margin_per_ha).to eq(870.0)

    get harvest_app_reports_path(locale: "en"), headers: native_headers
    expect(response.body).to include("11.5 t/ha").and include("Margin 870 USD a hectare")

    get download_app_reports_path(format: :json, locale: "en"), headers: native_headers
    seasons = JSON.parse(response.body)["fields"].first["seasons"]
    expect(seasons.filter_map { |s| s["harvest"] }.first).to include("yield" => 11.5, "margin_per_ha" => 870)
  end

  it "refuses a harvest for a season that has not come, and another farmer's crop" do
    future = create(:field_crop, field: field, season_year: Date.current.year + 1, crop_name: "Soybeans", scientific_name: "Glycine max")
    patch app_field_harvest_path(field, future, locale: "en"), headers: native_headers, params: { harvest: { yield_amount: "3", yield_unit: "t", area_basis: "ha" } }
    expect(future.reload.yield_amount).to be_nil

    other = create(:field_crop)
    patch app_field_harvest_path(field, other, locale: "en"), headers: native_headers, params: { harvest: { yield_amount: "3" } }
    expect(response).to have_http_status(:not_found)
  end
end
