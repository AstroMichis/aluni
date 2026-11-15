require "rails_helper"

RSpec.describe "My fields", type: :system do
  before { driven_by(:cuprite) }

  def next_step = all("button", text: I18n.t("fields.new.next")).find(&:visible?).click
  def on_step(key) = expect(page).to have_css("h1", text: I18n.t("fields.new.steps.#{key}.question"), wait: 5)

  it "adds a field through the conversation and lands on it" do
    visit new_menu_field_path(locale: "en")
    on_step(:location)
    next_step
    on_step(:found)
    find("input[name='confirmed[]'][value='soil_type']", visible: :all).find(:xpath, "..").click
    next_step

    on_step(:boundary)
    fill_in "answers[name]", with: "Road field"
    find("label", text: I18n.t("fields.options.boundary.drawn")).click
    fill_in "answers[area]", with: "12.5"
    next_step

    on_step(:crop)
    find("label", text: I18n.t("fields.options.current_crop.wheat")).click
    expect(page).to have_css(".onboarding__plot .plot.plot--grain")

    next_step until page.has_css?("h1", text: I18n.t("fields.new.steps.goals.question"), wait: 0.5)
    %w[soil water income].each { |goal| find(".choice--rank label", text: I18n.t("fields.options.goals.#{goal}")).click }
    expect(page).to have_css(".choice--rank label[data-order='3']")
    expect(page).to have_css(".choice--rank input[value='erosion'][disabled]", visible: :all)

    next_step
    on_step(:done)
    expect(page).to have_css(".review__row", text: "Road field")
    click_button I18n.t("fields.new.save")

    expect(page).to have_css("h1", text: "Road field", wait: 5)
    expect(page).to have_content(I18n.t("fields.create.added"))
    expect(page).to have_css(".plot--grain .plot__plant", count: 12)
    expect_no_server_errors!
  end

  it "confirms a value in place and keeps the page where it was" do
    visit menu_field_path("north", locale: "en")

    within("#reading-north-soil_texture") { click_button I18n.t("fields.actions.confirm") }
    expect(page).to have_css("#reading-north-soil_texture.reading--confirmed", wait: 5)
    expect(page).to have_no_css("a[href='#reading-north-soil_texture']")
  end

  it "plants a crop on the empty field" do
    visit menu_field_path("home", locale: "en")

    within(".field-hero__crop") do
      find("label", text: I18n.t("fields.options.current_crop.soybeans")).click
      click_button I18n.t("fields.show.plant")
    end
    expect(page).to have_css(".field-hero .plot--leafy .plot__plant", count: 12, wait: 5)
  end
end
