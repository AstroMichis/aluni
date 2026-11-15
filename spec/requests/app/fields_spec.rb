require "rails_helper"

RSpec.describe "App fields", type: :request do
  let(:user) { create(:user) }
  let(:farm) { create(:farm, user: user) }
  let(:field) { create(:field, :unlocated, farm: farm) }
  let(:setup) do
    { latitude: "4.6", longitude: "-74.08", place_label: "Bogotá", country_code: "CO", admin_area: "Bogotá",
      location_source: "typed", crop_name: "papa", irrigation: "rainfed", area: "2.5", area_unit: "hectares" }
  end

  before { sign_in_as(user) }

  it "saves the finder's pin and basics on the main field and lands on the home recap" do
    patch app_field_path(field, locale: "en"), params: setup, headers: native_headers

    expect(response).to redirect_to(app_root_path(locale: "en"))
    expect(response).to have_http_status(:see_other)
    follow_redirect!(headers: native_headers)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("app.fields.update.saved")).and include(I18n.t("app.home.show.recap_title"))
    expect(response.body).to include("4.6000").and include("-74.0800")

    expect(field.reload).to have_attributes(latitude: 4.6, longitude: -74.08, location_confidence: "confirmed", location_source: "typed",
                                            place_label: "Bogotá", irrigation: "rainfed", area: 2.5, area_unit: "hectares")
    expect(field.field_crops.sole).to have_attributes(crop_name: "Potato", scientific_name: "Solanum tuberosum", source: "farmer")
    expect(farm.reload).to have_attributes(country_code: "CO", admin_area: "Bogotá")
    expect(user.reload).to be_onboarding_complete
  end

  it "sends the person back with the reason when there is no pin" do
    patch app_field_path(field, locale: "en"), params: setup.except(:latitude, :longitude),
                                               headers: native_headers.merge("HTTP_REFERER" => "http://www.example.com/en")

    expect(response).to redirect_to("http://www.example.com/en")
    expect(response).to have_http_status(:see_other)
    follow_redirect!
    expect(response.body).to include(I18n.t("finder.errors.pin_required"))
    expect(field.reload.latitude).to be_nil
  end

  it "knows only the person's own fields" do
    other = create(:field)

    patch app_field_path(other, locale: "en"), params: setup, headers: native_headers
    expect(response).to have_http_status(:not_found)

    patch app_field_path(field, locale: "en"), params: setup
    expect(response).to have_http_status(:see_other)
  end

  it "answers 404 when the account has no farm yet" do
    patch app_field_path(1, locale: "en"), params: setup, headers: native_headers

    expect(response).to have_http_status(:not_found)
  end

  it "requires a session" do
    cookies.delete("session_id")

    patch app_field_path(field, locale: "en"), params: setup, headers: native_headers

    expect(response).to redirect_to(sign_in_path(locale: "en"))
  end

  it "closes to browsers with the kill switch" do
    with_native_web_access(false) do
      patch app_field_path(field, locale: "en"), params: setup
    end

    expect(response).to redirect_to(root_path(locale: "en"))
    expect(field.reload.latitude).to be_nil
  end
end
