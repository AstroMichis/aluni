require "rails_helper"

RSpec.describe "Field station catalogue", type: :request do
  it "renders the catalogue in English with both models, the sensors and the specs" do
    get devices_path(locale: "en")

    expect(response).to have_http_status(:ok)
    body = response.body
    expect(body).to include('lang="en"').and include(I18n.t("devices.show.headline"))
    expect(body).to include(I18n.t("devices.show.models.lite.name")).and include(I18n.t("devices.show.models.pro.name"))
    DevicesController::SENSORS.each { |sensor| expect(body).to include(CGI.escapeHTML(I18n.t("devices.show.sensors.#{sensor}.title"))) }
    DevicesController::SPEC_ROWS.each { |row| expect(body).to include(CGI.escapeHTML(I18n.t("devices.show.specs.rows.#{row}.label"))) }
    expect(body).to include('class="device-art"').and include('class="device-chart"')
  end

  it "renders the catalogue in Spanish under /es" do
    get devices_path(locale: "es")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('lang="es"').and include(I18n.t("devices.show.headline", locale: :es))
  end

  it "is linked from the landing page and the footer" do
    get "/en"

    expect(response.body).to include(%(href="#{devices_path(locale: "en")}"))
    expect(response.body).to include(I18n.t("pages.home.devices_teaser.cta"))
  end
end
