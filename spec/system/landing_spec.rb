require "rails_helper"

RSpec.describe "Landing page", type: :system do
  before { driven_by(:cuprite) }

  it "renders the hero and runs its JavaScript without errors" do
    visit root_path(locale: "en")

    expect(page).to have_content(I18n.t("pages.home.headline"))
    expect(page).to have_css(".landing__hero-content--visible", wait: 5)
    expect_no_server_errors!
  end

  it "switches the theme" do
    visit root_path(locale: "en")

    find("button[data-action='theme#toggle']").click
    expect(page).to have_css("html[data-theme='light']")
  end
end
