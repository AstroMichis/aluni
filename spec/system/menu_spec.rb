require "rails_helper"

RSpec.describe "Main menu dial and its sections", type: :system do
  let(:user) { create(:user, display_name: "Ana") }
  let!(:field) { create_farm_for(user) }

  before do
    driven_by_cuprite
    browser_sign_in(user)
  end

  it "turns with the arrow keys and opens a section from the hub" do
    visit app_root_path(locale: "en")

    page.execute_script("document.querySelector('.dial__svg').focus()")
    page.send_keys(:right)
    expect(page).to have_css(".dial__hub-title", text: I18n.t("app.home.show.sections.crops.title"), wait: 5)

    find(".dial__hub").click
    expect(page).to have_css("dialog.dial-panel[open]", wait: 5)
    find("button[aria-label='#{I18n.t("app.home.show.back")}']").click
    expect(page).to have_no_css("dialog.dial-panel[open]", wait: 5)
    expect_no_server_errors!
  end

  it "edits the field in one form and takes a source suggestion" do
    visit app_field_path(field, locale: "en")
    click_link I18n.t("app.fields.show.edit")

    find("input[name='values[irrigation]'][value='drip']", visible: :all).find(:xpath, "..").click
    find("#field-soil_texture .edit-field__suggestion").click
    click_button I18n.t("app.fields.edit.save")

    expect(page).to have_content(I18n.t("app.fields.update.saved"), wait: 5)
    expect(page).to have_css("#reading-#{field.id}-soil_texture.reading--confirmed")
    expect(field.reload).to have_attributes(irrigation: "drip", soil: include("texture" => "medium"))
  end

  it "shows a day's weather at the pin under the pointer" do
    visit app_weather_path(locale: "en")

    find("#chart-temperature .chart__svg").hover
    expect(page).to have_css("#chart-temperature .chart__tooltip:not([hidden])", text: "°C", wait: 5)
    expect_no_server_errors!
  end
end
