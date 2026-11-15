require "rails_helper"

RSpec.describe "Main menu dial", type: :system do
  before { driven_by(:cuprite) }

  it "turns with the arrow keys and updates the hub" do
    visit menu_path(locale: "en")

    page.execute_script("document.querySelector('.dial__svg').focus()")
    page.send_keys(:right)
    expect(page).to have_css(".dial__hub-title", text: I18n.t("pages.menu.sections.crops.title"), wait: 5)
    expect(page).to have_css(".dial__sector--selected[data-tone='crops']", visible: :all)
    expect_no_server_errors!
  end

  it "turns when a wedge is tapped and opens the section from the hub" do
    visit menu_path(locale: "en")

    find(".dial__sector[data-tone='weather']", visible: :all).trigger("click")
    expect(page).to have_css(".dial__hub-title", text: I18n.t("pages.menu.sections.weather.title"), wait: 5)

    find(".dial__hub").click
    expect(page).to have_css("dialog.dial-panel[open]", wait: 5)
    expect(page).to have_content(I18n.t("pages.menu.sections.weather.options.forecast.title"))

    find("button[aria-label='#{I18n.t("pages.menu.back")}']").click
    expect(page).to have_no_css("dialog.dial-panel[open]", wait: 5)
  end

  it "opens the fields panel from the add field button" do
    visit menu_path(locale: "en")

    click_button I18n.t("pages.menu.add_field")
    expect(page).to have_css("dialog.dial-panel[open]", wait: 5)
    expect(page).to have_content(I18n.t("pages.menu.sections.fields.options.add.title"))
  end
end
