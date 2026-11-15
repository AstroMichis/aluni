require "rails_helper"

# The mascot runs on a real page under headless Chrome with js_errors: true, so
# any uncaught exception on either path (WebGL or the SVG twin) fails here. The
# landing mounts it in preloader mode: centred while the page loads, then the
# move to the corner, the wave and the bubble.
RSpec.describe "Mascot", type: :system do
  before { driven_by_cuprite }

  let(:greeting) { I18n.t("mascot.greeting", app_name: I18n.t("app_name")) }

  # skip_welcome! (spec/support/cuprite_helpers.rb) sets the preferences cookie:
  # a returning visitor, no welcome overlay, so the go signal is the derived
  # preloader:ready (hero revealed, 0.9 s, or the 2.5 s fallback).

  it "sprouts in the centre, moves to its corner and asks for the field" do
    skip_welcome!
    visit root_path(locale: "en")

    expect(page).to have_no_css("#welcome")
    # The controller measured the centre at connect (the CSS carried the first paint).
    expect(page.evaluate_script("document.querySelector('.mascot').style.getPropertyValue('--mascot-pre-scale')")).not_to be_empty

    expect(page).to have_css(".mascot--arrived, .mascot--fallback", wait: 10)
    expect(page).to have_no_css(".mascot--centered")
    expect(page).to have_no_css(".mascot--leaving")
    expect(page).to have_css(".mascot__bubble--visible", text: greeting, wait: 5)
    expect(page).to have_css(".mascot__bubble--visible", text: I18n.t("mascot.question"))
    within(".mascot__bubble") { expect(page).to have_button(I18n.t("mascot.find_my_field")) }

    within(".mascot__bubble") { click_link I18n.t("mascot.show_me_around") }

    expect(page).to have_no_css(".mascot__bubble--visible")
    expect(page).to have_css(".mascot__bubble", visible: :hidden)
    expect_no_server_errors!
  end

  it "stands still as the SVG twin in its corner when motion is reduced" do
    skip_welcome!
    page.driver.browser.page.command("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])

    visit root_path(locale: "en")

    expect(page).to have_css(".mascot--fallback.mascot--arrived .mascot-avatar", wait: 10)
    expect(page).to have_no_css(".mascot--centered")
    expect(page).to have_css(".mascot__bubble--visible", text: greeting)
    expect(page).to have_no_css(".mascot__canvas canvas")
    expect_no_server_errors!
  end

  it "shows the intro in its first bubble on a first visit, and survives an early welcome:done" do
    visit root_path(locale: "en")
    page.execute_script("window.dispatchEvent(new CustomEvent('welcome:done'))")

    expect(page).to have_css(".mascot--arrived, .mascot--fallback", wait: 10)
    expect(page).to have_no_css(".mascot--centered")
    expect(page).to have_css(".mascot__bubble--visible [data-controller='intro']", wait: 5)
    expect(page).to have_button(I18n.t("intro.done"))
    expect_no_server_errors!
  end
end
