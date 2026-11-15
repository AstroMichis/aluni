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
    selector = ".crop-map__cell[data-index='#{index}']"
    find(selector)
    # Scrolled at once (not smoothly), so the rectangle read next is where the cell is.
    rect = page.evaluate_script(<<~JS)
      (() => { const cell = document.querySelector("#{selector}"); cell.scrollIntoView({ block: "center", behavior: "instant" }); return cell.getBoundingClientRect().toJSON() })()
    JS
    { x: rect["x"] + (rect["width"] / 2), y: rect["y"] + (rect["height"] / 2) }
  end

  it "splits the field with numbers, paints the map and saves" do
    visit edit_app_field_layout_path(field, locale: "en")
    expect(page).to have_css(".crop-map__cell[data-slot='0']", count: 100)

    # Adding a crop to a fully planted field splits it in equal parts: name it and it is done.
    click_button I18n.t("app.field_layouts.edit.add")
    all("input[name='crops[][crop]']").last.fill_in(with: "Beans")
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

  it "splits the field in two taps from the home: the dial's first option, then add a crop" do
    visit app_root_path(locale: "en")
    click_link I18n.t("app.home.show.sections.fields.options.planting.title")
    expect(page).to have_css(".crop-map--editable", wait: 5)

    click_button I18n.t("app.field_layouts.edit.add")
    all("input[name='crops[][crop]']").last.fill_in(with: "Beans")
    click_button I18n.t("app.field_layouts.edit.save")

    expect(page).to have_content(I18n.t("app.field_layouts.update.saved", year: Date.current.year), wait: 5)
    expect(field.field_crops.where(season_year: Date.current.year).pluck(:crop_name, :share)).to contain_exactly([ "Corn", 0.5 ], [ "Beans", 0.5 ])
  end

  it "plans the field right where it opens, then moves to its rotation without leaving the page" do
    visit app_field_path(field, locale: "en")
    page.execute_script("window.__same_page = true")
    expect(page).to have_css(".crop-map--editable")

    click_button I18n.t("app.field_layouts.edit.add")
    all("input[name='crops[][crop]']").last.fill_in(with: "Beans")
    click_button I18n.t("app.field_layouts.edit.save")
    expect(page).to have_content(I18n.t("app.field_layouts.update.saved", year: Date.current.year), wait: 5)
    expect(page).to have_css(".crop-map__cell[data-slot='1']", count: 50, wait: 5)

    within(".workspace__tabs") { click_link I18n.t("app.fields.workspace.tabs.rotation") }
    expect(page).to have_css(".workspace__tabs [aria-current='page']", text: I18n.t("app.fields.workspace.tabs.rotation"), wait: 5)
    expect(page.evaluate_script("window.__same_page")).to be(true)
    # The tab advanced the URL (data-turbo-action="advance"), so Back and a reload follow it.
    expect(page).to have_current_path(app_field_rotation_path(field, locale: "en"))
    expect_no_server_errors!
  end

  # A touch swipe, as the browser reports it, across the page's content.
  def swipe(from_x, to_x, y: 400, to_y: y)
    page.execute_script(<<~JS)
      (() => {
        const target = document.querySelector("main h1") || document.querySelector("main")
        const touch = (x, y) => new Touch({ identifier: 1, target, clientX: x, clientY: y })
        target.dispatchEvent(new TouchEvent("touchstart", { touches: [touch(#{from_x}, #{y})], changedTouches: [touch(#{from_x}, #{y})], bubbles: true }))
        target.dispatchEvent(new TouchEvent("touchend", { touches: [], changedTouches: [touch(#{to_x}, #{to_y})], bubbles: true }))
      })()
    JS
  end

  it "swipes between the field's tabs" do
    visit app_field_path(field, locale: "en")
    expect(page).to have_css(".workspace__tabs [aria-current='page']", text: I18n.t("app.fields.workspace.tabs.summary"))

    swipe(600, 300)
    expect(page).to have_css(".workspace__tabs [aria-current='page']", text: I18n.t("app.fields.workspace.tabs.rotation"), wait: 5)
    expect(page).to have_css(".strategy", wait: 5)
    swipe(600, 300)
    expect(page).to have_css(".workspace__tabs [aria-current='page']", text: I18n.t("app.fields.workspace.tabs.data"), wait: 5)
    swipe(300, 600)
    expect(page).to have_css(".workspace__tabs [aria-current='page']", text: I18n.t("app.fields.workspace.tabs.rotation"), wait: 5)

    # A mostly vertical drag is a scroll, not a swipe.
    swipe(600, 560, y: 100, to_y: 400)
    expect(page).to have_css(".workspace__tabs [aria-current='page']", text: I18n.t("app.fields.workspace.tabs.rotation"))
    expect_no_server_errors!
  end
end
