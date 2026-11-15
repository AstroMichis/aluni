require "rails_helper"

# The field finder on the real landing page under headless Chrome. The geocoder is
# doubled at the Ruby level and the map's tile hosts are blocked in the browser, so
# nothing leaves the machine; an uncaught exception in finder_controller.js,
# field_map_controller.js or Leaflet fails the example (js_errors).
# The tile block comes from spec/support/cuprite_helpers.rb (url_blacklist); the
# after hook proves no tile was received.
RSpec.describe "Field finder", type: :system do
  let(:ames) do
    { label: "Ames, Story County, Iowa, United States", display: "Ames, Iowa", latitude: 42.030781, longitude: -93.631913,
      country_code: "US", country: "United States", admin_area: "Iowa" }
  end
  let(:geocoder) { instance_double(Geocoding::Client, reverse: ames, search: [ ames ], last_error: nil) }

  before do
    driven_by_cuprite
    allow(Geocoding::Client).to receive(:new).and_return(geocoder)
    skip_welcome!
  end

  after { expect(tile_requests).to be_empty }

  # Tile URLs the page actually received bytes for (an aborted request has none).
  def tile_requests
    page.evaluate_script("performance.getEntriesByType('resource').filter(e => /openstreetmap|arcgisonline/.test(e.name) && e.responseStatus > 0).map(e => e.name)")
  end

  # Cuprite opens its pages in their own browser context, so the grant names it.
  def grant_geolocation(latitude:, longitude:)
    browser = page.driver.browser
    browser.command("Browser.grantPermissions", permissions: [ "geolocation" ], origin: Capybara.current_session.server.base_url,
                                                browserContextId: browser.page.context_id)
    browser.page.command("Emulation.setGeolocationOverride", latitude: latitude, longitude: longitude, accuracy: 50)
  end

  def open_finder
    expect(page).to have_css(".landing__hero-content--visible", wait: 5)
    page.execute_script("window.dispatchEvent(new CustomEvent('mascot:lets-go'))")
    expect(page).to have_css("#finder:not([hidden])", wait: 5)
    expect(page).to have_css("#finder-companion[data-mascot-dock]", visible: :all)
  end

  def hidden_value(name)
    find("#finder-save input[name='#{name}']", visible: :all).value
  end

  it "finds the field from the device position, takes the basics and fills the passkey step" do
    visit root_path(locale: "en")
    grant_geolocation(latitude: 42.0, longitude: -93.75)
    open_finder

    within("#finder") do
      expect(page).to have_content(I18n.t("finder.steps.locate.title"))
      expect(page).to have_css(".finder__map.leaflet-container", wait: 10)
      expect(page).to have_button(I18n.t("finder.steps.locate.confirm"), disabled: true)

      click_button I18n.t("finder.steps.locate.use_my_location")
      expect(page).to have_css(".finder__status", text: I18n.t("finder.status.located"), wait: 10)
      expect(page).to have_css(".finder__pin", wait: 5)
      expect(page).to have_button(I18n.t("finder.steps.locate.confirm"), disabled: false)

      click_button I18n.t("finder.steps.locate.confirm")
      expect(page).to have_content(I18n.t("places.reverse.near", place: "Ames, Iowa"), wait: 10)
      expect(page).to have_content(I18n.t("finder.steps.basics.title"))
      expect(page).to have_css(".finder__kicker", text: /#{Regexp.escape(I18n.t("finder.kicker", index: 2, total: 3))}/i)
      # A US pin defaults the area unit to acres.
      expect(find("input[name='area_unit'][value='acres']", visible: :all)).to be_checked

      fill_in "finder-crop", with: "maíz"
      find("label.finder__chip", text: I18n.t("onboarding.values.irrigation.irrigated")).click
      fill_in "finder-area", with: "12.5"
      click_button I18n.t("finder.steps.basics.continue")

      expect(page).to have_content(I18n.t("finder.steps.save.title"))
      expect(page).to have_field("finder-name")
      expect(page).to have_button(I18n.t("finder.steps.save.create_passkey"))
      expect(hidden_value("latitude")).to eq("42.00000")
      expect(hidden_value("longitude")).to eq("-93.75000")
      expect(hidden_value("place_label")).to eq("Ames, Iowa")
      expect(hidden_value("country_code")).to eq("US")
      expect(hidden_value("admin_area")).to eq("Iowa")
      expect(hidden_value("location_source")).to eq("geolocation")
      expect(hidden_value("crop_name")).to eq("maíz")
      expect(hidden_value("irrigation")).to eq("irrigated")
      expect(hidden_value("area")).to eq("12.5")
      expect(hidden_value("area_unit")).to eq("acres")
      expect(find("#finder-save input[name='locale']", visible: :all).value).to eq("en")
    end

    # The draft survives a reload, open where it was.
    visit root_path(locale: "en")
    expect(page).to have_css("#finder:not([hidden])", wait: 5)
    expect(page).to have_content(I18n.t("finder.steps.save.title"))
    expect(hidden_value("crop_name")).to eq("maíz")

    expect(geocoder).to have_received(:reverse).with(latitude: 42.0, longitude: -93.75, locale: :en)
    expect_no_server_errors!
  end

  it "keeps Escape for the fields and closes only from the panel, a heading, a button or the map" do
    visit root_path(locale: "en")
    # A draft on the basics step, as a reload after "This is my field" would find it.
    page.execute_script("window.sessionStorage.setItem('aluni.finder', JSON.stringify({ open: true, step: 'basics', latitude: '42', longitude: '-93.75', location_source: 'map' }))")
    visit root_path(locale: "en")
    expect(page).to have_css("#finder:not([hidden])", wait: 5)
    expect(page).to have_content(I18n.t("finder.steps.basics.title"))

    # Escape in the crop input dismisses the datalist and leaves the field; the panel stays.
    find("#finder-crop").send_keys("maize", :escape)
    expect(page).to have_css("#finder:not([hidden])")
    expect(page).to have_content(I18n.t("finder.steps.basics.title"))
    expect(find("#finder-crop").value).to eq("maize")
    expect(page.evaluate_script("document.activeElement.id")).not_to eq("finder-crop")

    # Escape in the search field only leaves it too.
    click_button I18n.t("finder.back")
    find("#finder-query").send_keys("Ames", :escape)
    expect(page).to have_css("#finder:not([hidden])")

    # From the step heading, Escape closes the panel.
    find("#finder-step-locate").send_keys(:escape)
    expect(page).to have_css("#finder[hidden]", visible: :all)

    # Opening it again resumes where it was; Escape on a button closes it as well.
    page.execute_script("window.dispatchEvent(new CustomEvent('mascot:lets-go'))")
    expect(page).to have_css("#finder:not([hidden])", wait: 5)
    find("#finder .panel__icon-button[data-action='finder#close']").send_keys(:escape)
    expect(page).to have_css("#finder[hidden]", visible: :all)
    expect_no_server_errors!
  end

  it "finds the field from a town search, moves on to the basics, and closes with Escape" do
    visit root_path(locale: "es")
    open_finder

    within("#finder") do
      expect(page).to have_content(I18n.t("places.index.hint", locale: :es))
      fill_in "finder-query", with: "Ames, Iowa"
      click_button I18n.t("finder.steps.locate.search", locale: :es)

      expect(page).to have_css("#place-results [role='listbox'] [role='option']", wait: 10)
      find("#place-results [role='option']", match: :first).click
      expect(page).to have_css("#place-results [role='option'][aria-selected='true']")
      expect(page).to have_button(I18n.t("finder.steps.locate.confirm", locale: :es), disabled: false)

      click_button I18n.t("finder.steps.locate.confirm", locale: :es)
      expect(page).to have_content(I18n.t("places.reverse.near", place: "Ames, Iowa", locale: :es), wait: 10)
      expect(page).to have_content(I18n.t("finder.steps.basics.title", locale: :es))

      click_button I18n.t("finder.steps.basics.skip", locale: :es)
      expect(page).to have_content(I18n.t("finder.steps.save.title", locale: :es))
      expect(hidden_value("latitude")).to eq("42.03078")
      expect(hidden_value("location_source")).to eq("typed")
      expect(hidden_value("crop_name")).to eq("")

      click_button I18n.t("finder.back", locale: :es)
      expect(page).to have_content(I18n.t("finder.steps.basics.title", locale: :es))
      find("#finder-step-basics").send_keys(:escape)
    end

    expect(page).to have_css("#finder[hidden]", visible: :all)
    expect(geocoder).to have_received(:search).with("Ames, Iowa", locale: :es)
    expect_no_server_errors!
  end
end
