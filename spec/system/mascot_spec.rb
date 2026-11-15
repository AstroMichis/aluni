require "rails_helper"

# The mascot runs on a real page under headless Chrome with js_errors: true, so
# any uncaught exception on either path (WebGL or the SVG twin) fails here.
RSpec.describe "Mascot", type: :system do
  before { driven_by(:cuprite) }

  let(:greeting) { I18n.t("mascot.greeting", app_name: I18n.t("app_name")) }

  it "walks in, greets, and steps back for the tour" do
    visit root_path(locale: "en")

    expect(page).to have_css(".mascot--arrived, .mascot--fallback", wait: 10)
    expect(page).to have_css(".mascot__bubble--visible", text: greeting, wait: 5)
    expect(page).to have_css(".mascot__bubble--visible", text: I18n.t("mascot.question"))

    within(".mascot__bubble") { click_link I18n.t("mascot.show_me_around") }

    expect(page).to have_no_css(".mascot__bubble--visible")
    expect(page).to have_css(".mascot__bubble", visible: :hidden)
    expect_no_server_errors!
  end

  it "stands still as the SVG twin when motion is reduced" do
    page.driver.browser.page.command("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])

    visit root_path(locale: "en")

    expect(page).to have_css(".mascot--fallback.mascot--arrived .mascot-avatar", wait: 10)
    expect(page).to have_css(".mascot__bubble--visible", text: greeting)
    expect(page).to have_no_css(".mascot__canvas canvas")
    expect_no_server_errors!
  end
end
