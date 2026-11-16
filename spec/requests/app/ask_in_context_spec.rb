require "rails_helper"

# Water and area are not asked at sign-up: each is asked where it changes something.
RSpec.describe "Questions asked in context", type: :request do
  let(:user) { create(:user) }
  let!(:field) { create_farm_for(user) }

  before { sign_in_as(user) }

  it "asks on the Rotation tab whether the field is watered, and returns there with the answer" do
    field.update!(irrigation: :unknown)
    get app_field_rotation_path(field, locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.rotations.water_question.title")).and include(I18n.t("app.rotations.water_question.why"))

    patch app_field_path(field, locale: "en"), params: { values: { irrigation: "irrigated" }, return_to: "rotation", zone: 0 }, headers: native_headers
    expect(response).to redirect_to(app_field_rotation_path(field, zone: 0, locale: "en"))
    expect(field.reload).to be_irrigation_irrigated

    get app_field_rotation_path(field, locale: "en"), headers: native_headers
    expect(response.body).not_to include(I18n.t("app.rotations.water_question.title"))
  end

  it "asks for the area where the reports need it, and leaves out the tonnes until then" do
    field.update!(area: nil)
    get app_reports_path(locale: "en"), headers: native_headers
    expect(response.body).to include("has no area yet").and include("focus=area")

    get harvest_app_reports_path(locale: "en"), headers: native_headers
    expect(response.body).to include(CGI.escapeHTML(I18n.t("app.reports.harvest.add_area")))
    expect(response.body).not_to match(/\d t on this field/)
  end

  it "asks a new field only for its name in the details step" do
    get new_app_field_path(locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.fields.new.steps.details.question"))
    expect(response.body).not_to include('name="field[area]"')
    expect(response.body).not_to include('name="field[irrigation]"')
  end
end
