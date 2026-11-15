require "rails_helper"

# The emailed sign-in code end to end under headless Chrome. The finder's save step offers the two
# cards; "Email me a code" posts the finder's draft with the address, the code is read from the
# delivered mail and typed back, and the person lands in the app with the field saved and the
# passkey suggestion. A returning person on /sign_in mistypes the code once, then gets in. The
# geocoder is doubled and the map's tile hosts are blocked as in finder_spec.rb; an uncaught
# exception in choice_controller.js, sign_in_code_controller.js or finder_controller.js fails
# the example (js_errors).
RSpec.describe "Sign-in codes", type: :system do
  let(:ames) do
    { label: "Ames, Story County, Iowa, United States", display: "Ames, Iowa", latitude: 42.030781, longitude: -93.631913,
      country_code: "US", country: "United States", admin_area: "Iowa" }
  end
  let(:geocoder) { instance_double(Geocoding::Client, reverse: ames, search: [ ames ], last_error: nil) }

  before do
    driven_by_cuprite
    allow(Geocoding::Client).to receive(:new).and_return(geocoder)
    ActionMailer::Base.deliveries.clear
    skip_welcome!
  end

  after { expect(tile_requests).to be_empty }

  def tile_requests
    page.evaluate_script("performance.getEntriesByType('resource').filter(e => /openstreetmap|arcgisonline/.test(e.name) && e.responseStatus > 0).map(e => e.name)")
  end

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
  end

  # The six digits from the last mail (its text part shows them as "123 456").
  def delivered_code
    mail = ActionMailer::Base.deliveries.last
    expect(mail).to be_present
    digits = mail.text_part.decoded[/\b\d{3} ?\d{3}\b/]
    expect(digits).to be_present
    digits.delete(" ")
  end

  def masked(email)
    "#{email[0]}***@#{email.split("@").last}"
  end

  it "saves the field through an emailed code and suggests a passkey" do
    expect_no_server_errors!
    visit root_path(locale: "en")
    grant_geolocation(latitude: 42.0, longitude: -93.75)
    open_finder

    within("#finder") do
      expect(page).to have_css(".finder__map.leaflet-container", wait: 10)
      # The step asked the device as it opened; the pin lands without a tap.
      expect(page).to have_button(I18n.t("finder.steps.locate.confirm"), disabled: false, wait: 10)
      click_button I18n.t("finder.steps.locate.confirm")
      expect(page).to have_content(I18n.t("finder.steps.basics.title"), wait: 10)
      fill_in "finder-crop", with: "maíz"
      click_button I18n.t("finder.steps.basics.continue")

      # Two equal cards, both folded; the footer's passkey button waits for its card.
      expect(page).to have_content(I18n.t("finder.steps.save.title"))
      expect(page).to have_content(I18n.t("finder.steps.save.line_signed_out"))
      expect(page).to have_button(I18n.t("sign_in_codes.choice.passkey_title"))
      expect(page).to have_button(I18n.t("sign_in_codes.choice.email_title"))
      expect(page).not_to have_field("finder-name")
      expect(page).not_to have_field("finder-code-email")
      expect(page).not_to have_button(I18n.t("finder.steps.save.create_passkey"))

      click_button I18n.t("sign_in_codes.choice.passkey_title")
      expect(page).to have_field("finder-name")
      expect(page).to have_button(I18n.t("finder.steps.save.create_passkey"))
      expect(find("#finder-save input[name='latitude']", visible: :all).value).to eq("42.00000")

      click_button I18n.t("sign_in_codes.choice.email_title")
      expect(page).to have_field("finder-code-email")
      expect(page).not_to have_field("finder-name")
      expect(page).not_to have_button(I18n.t("finder.steps.save.create_passkey"))
      expect(find("#finder-code input[name='latitude']", visible: :all).value).to eq("42.00000")
      expect(find("#finder-code input[name='crop_name']", visible: :all).value).to eq("maíz")

      fill_in "finder-code-name", with: "Ada"
      fill_in "finder-code-email", with: "ada@example.com"
      click_button I18n.t("sign_in_codes.choice.send_button")

      expect(page).to have_content(I18n.t("sign_in_codes.code.sent", destination: "a***@example.com"), wait: 10)
      expect(page).to have_content(I18n.t("finder.steps.save.line_code"))
      expect(page).to have_button(I18n.t("sign_in_codes.code.continue"), disabled: true)
      expect(page).to have_button(I18n.t("sign_in_codes.code.resend"), disabled: true)
      expect(page).to have_css(".code-entry__countdown", text: /\d+/)
      expect(page).to have_link(I18n.t("sign_in_codes.code.use_passkey"))
    end
    expect(page).not_to have_button(I18n.t("finder.steps.save.create_passkey"))

    code = delivered_code
    within("#finder") do
      fill_in I18n.t("sign_in_codes.code.label"), with: code
      expect(find("#finder-code-input").value).to eq("#{code[0, 3]} #{code[3, 3]}")
      click_button I18n.t("sign_in_codes.code.continue")
    end

    expect(page).to have_current_path("/en/app", wait: 10)
    expect(page).to have_css(".toast", text: I18n.t("sessions.create.suggest_passkey"), wait: 5)
    expect(page).to have_link(I18n.t("sessions.create.suggest_passkey_action"), href: "/en/passkeys")
    expect(page.evaluate_script("window.sessionStorage.getItem('aluni.finder')")).to be_nil

    user = User.find_by!(email_address: "ada@example.com")
    expect(user).to have_attributes(display_name: "Ada", locale: "en")
    expect(user.email_verified_at).to be_present
    expect(user.sessions.sole.sign_in_method).to eq("email_code")
    field = user.farms.sole.fields.sole
    expect(field).to have_attributes(latitude: 42.0, longitude: -93.75, place_label: "Ames, Iowa", location_source: "geolocation")
    expect(field.field_crops.sole.scientific_name).to eq("Zea mays")
    expect_no_server_errors!
  end

  it "signs a returning person in from /sign_in after one wrong code" do
    expect_no_server_errors!
    user = create(:user, :with_email)

    visit sign_in_path(locale: "en")
    expect(page).to have_button(I18n.t("sign_in_codes.choice.passkey_title"))
    expect(page).not_to have_button(I18n.t("sessions.new.button"))
    expect(page).not_to have_field("auth-code-email")

    click_button I18n.t("sign_in_codes.choice.email_title")
    expect(page).not_to have_field("auth-code-name")
    fill_in "auth-code-email", with: user.email_address
    click_button I18n.t("sign_in_codes.choice.send_button")
    expect(page).to have_content(I18n.t("sign_in_codes.code.sent", destination: masked(user.email_address)), wait: 10)
    expect(page).to have_current_path("/en/sign_in")

    code = delivered_code
    wrong = code == "000000" ? "111111" : "000000"
    fill_in I18n.t("sign_in_codes.code.label"), with: wrong
    click_button I18n.t("sign_in_codes.code.continue")
    expect(page).to have_content(I18n.t("sign_in_codes.code.wrong"), wait: 10)
    expect(page).to have_content(I18n.t("sign_in_codes.code.attempts_left", count: SignInCode::MAX_ATTEMPTS - 1))
    expect(page).to have_current_path("/en/sign_in")
    expect(find("#auth-code-input").value).to eq("")

    fill_in I18n.t("sign_in_codes.code.label"), with: code
    click_button I18n.t("sign_in_codes.code.continue")
    expect(page).to have_current_path("/en/app", wait: 10)
    expect(page).to have_css(".toast", text: I18n.t("sessions.create.suggest_passkey"), wait: 5)

    expect(user.reload.email_verified_at).to be_present
    expect(user.sessions.sole.sign_in_method).to eq("email_code")
    expect_no_server_errors!
  end
end
