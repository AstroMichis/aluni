require "rails_helper"

RSpec.describe "Plan the planting", type: :system do
  let(:user) { create(:user, display_name: "Ana") }
  let!(:field) { create_farm_for(user).tap { |f| f.update!(area: 2) } }

  before do
    driven_by_cuprite
    browser_sign_in(user)
  end

  # Where a map cell is on screen, for the real mouse (Ferrum's).
  def centre_of(index)
    find(".crop-map__cell[data-index='#{index}']").scroll_to(:center)
    rect = page.evaluate_script("document.querySelector(\".crop-map__cell[data-index='#{index}']\").getBoundingClientRect().toJSON()")
    { x: rect["x"] + (rect["width"] / 2), y: rect["y"] + (rect["height"] / 2) }
  end

  it "splits the field with numbers, paints the map and saves" do
    visit edit_app_field_layout_path(field, locale: "en")
    expect(page).to have_css(".crop-map__cell[data-slot='0']", count: 100)

    click_button I18n.t("app.field_layouts.edit.add")
    all("input[name='crops[][crop]']").last.fill_in(with: "Beans")
    click_button I18n.t("app.field_layouts.edit.shortcuts.equal")
    expect(all("input[name='crops[][amount]']").map(&:value)).to eq(%w[1 1])
    expect(page).to have_css(".crop-map__cell[data-slot='1']", count: 50)
    expect(page).to have_css(".planner__total", text: I18n.t("app.field_layouts.edit.total.full"))

    # Paint two cells of the corn half with beans by dragging across them.
    mouse = page.driver.browser.mouse
    mouse.move(**centre_of(0))
    mouse.down
    mouse.move(**centre_of(1), steps: 4)
    mouse.up
    expect(page).to have_css(".crop-map__cell[data-slot='1']", count: 52)
    expect(all("input[name='crops[][amount]']").map(&:value)).to eq(%w[0.96 1.04])

    # The eraser, from the chips above the map, leaves a cell unplanted.
    within(".planner__brushes") { click_button I18n.t("app.field_layouts.edit.eraser") }
    mouse.move(**centre_of(99))
    mouse.down
    mouse.up
    expect(page).to have_css(".crop-map__cell[data-index='99'][data-slot='']")
    expect(page).to have_css(".planner__total", text: "0.02 ha")

    within(".planner__brushes") { click_button "Beans" }
    mouse.move(**centre_of(99))
    mouse.down
    mouse.up
    expect(page).to have_css(".crop-map__cell[data-index='99'][data-slot='1']")

    click_button I18n.t("app.field_layouts.edit.save")
    expect(page).to have_content(I18n.t("app.field_layouts.update.saved", year: Date.current.year), wait: 5)
    expect(page).to have_css("#planting .crop-map__cell[data-slot='0']", count: 52)
    expect(field.field_crops.where(season_year: Date.current.year).order(:share).pluck(:crop_name, :share)).to eq([ [ "Corn", 0.48 ], [ "Beans", 0.52 ] ])
    expect_no_server_errors!
  end
end
