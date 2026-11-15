require "rails_helper"

# Aluni's first bubble: language and comfort choices in character, then "Let's find
# your field". Returning visitors go straight to the second bubble.
RSpec.describe "Aluni's intro", type: :system do
  before { driven_by(:aluni_cuprite) }

  it "settles comfort choices in the first bubble and remembers them" do
    visit "/en"
    expect(page).to have_css(".mascot--arrived, .mascot--fallback", wait: 10)
    expect(page).to have_css("[data-controller='intro']", visible: :all)
    expect(page).to have_button(I18n.t("intro.done"))

    click_button I18n.t("intro.text_size")
    expect(page).to have_css("html[data-text-size='large']")

    click_button I18n.t("intro.done")
    expect(page).to have_button(I18n.t("mascot.find_my_field"), wait: 5)
    expect(page).not_to have_button(I18n.t("intro.done"))

    visit "/en"
    expect(page).to have_css(".mascot--arrived, .mascot--fallback", wait: 10)
    expect(page).to have_css("html[data-text-size='large']")
    expect(page).to have_button(I18n.t("mascot.find_my_field"))
    expect(page).not_to have_button(I18n.t("intro.done"))
    expect_no_server_errors!
  end

  it "switches to Spanish from the first bubble and keeps the bubble" do
    visit "/en"
    expect(page).to have_css(".mascot--arrived, .mascot--fallback", wait: 10)

    click_button I18n.t("intro.languages.es")

    expect(page).to have_css("html[lang='es']", wait: 10)
    expect(page).to have_content(I18n.t("pages.home.headline", locale: :es))
    expect(page).to have_css(".mascot--arrived, .mascot--fallback", wait: 10)
    expect(page).to have_button(I18n.t("intro.done", locale: :es))
    expect_no_server_errors!
  end
end
