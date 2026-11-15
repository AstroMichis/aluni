require "rails_helper"

RSpec.describe "Landing page", type: :system do
  before do
    driven_by_cuprite
    skip_welcome!
  end

  it "renders the hero and runs its JavaScript without errors" do
    visit root_path(locale: "en")

    expect(page).to have_content(I18n.t("pages.home.headline"))
    expect(page).to have_css(".landing__hero-content--visible", wait: 5)
    expect_no_server_errors!
  end

  it "activates a tour step on scroll and reaches the store section" do
    visit root_path(locale: "en")
    expect(page).to have_css(".landing__hero-content--visible", wait: 5)

    page.execute_script("document.getElementById('tour-step-3').scrollIntoView({ block: 'center', behavior: 'instant' })")
    expect(page).to have_css("#tour-step-3.tour-step--active", wait: 5)
    expect(page).to have_css(".tour-nav__dot[aria-current='step'][href='#tour-step-3']", visible: :all)

    page.execute_script("document.getElementById('get-the-app').scrollIntoView({ behavior: 'instant' })")
    expect(page).to have_css(".store-button--soon", count: 2, wait: 5)
    expect_no_server_errors!
  end

  it "switches the theme" do
    visit root_path(locale: "en")

    find("button[data-action='preferences#toggleTheme']").click
    expect(page).to have_css("html[data-theme='light']")
  end
end
