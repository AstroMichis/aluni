require "rails_helper"

RSpec.describe "Field workspace and next-up shortcuts", type: :request do
  let(:user) { create(:user, display_name: "Ana") }
  let!(:field) { create_farm_for(user) }

  before { sign_in_as(user) }

  it "serves every tab as a whole page and, inside the frame, only the frame" do
    { app_field_path(field, locale: "en") => "summary", edit_app_field_layout_path(field, locale: "en") => "planting",
      app_field_rotation_path(field, locale: "en") => "rotation", app_field_path(field, locale: "en", tab: "data") => "data" }.each do |path, tab|
      get path, headers: native_headers
      expect(response.body).to include("data-turbo-track").and include(I18n.t("app.fields.workspace.tabs.#{tab}"))
      expect(response.body).to match(%r{aria-current="page"[^>]*>#{I18n.t("app.fields.workspace.tabs.#{tab}")}<})

      # turbo-rails' minimal frame layout: no stylesheets, no screen bar.
      get path, headers: native_headers.merge("Turbo-Frame" => "workspace")
      expect(response.body).not_to include("data-turbo-track")
      expect(response.body).to include('id="workspace"')
    end
  end

  it "keeps the save message inside the frame after a save made in it" do
    patch app_field_path(field, locale: "en"), headers: native_headers.merge("Turbo-Frame" => "workspace"),
          params: { values: { irrigation: "drip" } }
    follow_redirect!(headers: native_headers.merge("Turbo-Frame" => "workspace"))

    expect(response.body).to include("workspace__flash").and include(I18n.t("app.fields.update.saved"))
  end

  it "puts what the farm needs next one tap from the home" do
    get app_root_path(locale: "en"), headers: native_headers

    expect(response.body).to include(I18n.t("app.home.show.shortcuts.title"))
    expect(response.body).to include(I18n.t("app.home.show.shortcuts.plan", year: Date.current.year + 1, name: "North field"))
    expect(response.body).to include(%(href="/en/app/fields/#{field.id}/layout/edit?year=#{Date.current.year + 1}"))
  end

  it "offers the first field when there is none" do
    field.destroy!
    get app_root_path(locale: "en"), headers: native_headers
    expect(response.body).to include(I18n.t("app.home.show.shortcuts.add")).and include(%(href="/en/app/fields/new"))
  end
end
