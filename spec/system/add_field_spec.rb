require "rails_helper"

RSpec.describe "Add a field", type: :system do
  let(:user) { create(:user) }

  before do
    create_farm_for(user)
    driven_by_cuprite
    browser_sign_in(user)
  end

  def step_shown = find(".field-wizard__step--current .field-wizard__count").text

  it "does not move on with a coordinate out of range, and says why" do
    visit new_app_field_path(locale: "en")
    fill_in I18n.t("app.fields.pin.latitude"), with: "-33.5961669"
    fill_in I18n.t("app.fields.pin.longitude"), with: "-708476706"
    first = step_shown

    click_button I18n.t("app.fields.new.next")

    expect(page).to have_css(".toast--error", text: I18n.t("app.fields.new.invalid_step"))
    expect(step_shown).to eq(first)
    message = page.evaluate_script("document.querySelector('input[name=\"field[longitude]\"]').validationMessage")
    expect(message).to eq(I18n.t("app.fields.pin.longitude_range"))

    fill_in I18n.t("app.fields.pin.longitude"), with: "-70.8476706"
    click_button I18n.t("app.fields.new.next")
    expect(step_shown).not_to eq(first)
  end

  it "asks for the crop when its months were picked" do
    visit new_app_field_path(locale: "en")
    fill_in I18n.t("app.fields.pin.latitude"), with: "-33.59"
    fill_in I18n.t("app.fields.pin.longitude"), with: "-70.84"
    click_button I18n.t("app.fields.new.next")
    find(".field-wizard__step--current").click_button(I18n.t("app.fields.new.next")) # the field's details, all optional here
    find(".field-wizard__step--current select[name='field[planting_month]']").find("option[value='9']").select_option
    crop_step = step_shown

    find(".field-wizard__step--current").click_button(I18n.t("app.fields.new.next"))

    expect(page).to have_css(".toast--error", text: I18n.t("app.fields.new.invalid_step"))
    expect(step_shown).to eq(crop_step)
    message = page.evaluate_script("document.querySelector('input[name=\"field[crop]\"]').validationMessage")
    expect(message).to eq(I18n.t("app.fields.new.crop_needed"))
  end

  it "takes the person back to the wrong step instead of sending in silence" do
    visit new_app_field_path(locale: "en")
    fill_in I18n.t("app.fields.pin.latitude"), with: "-33.59"
    fill_in I18n.t("app.fields.pin.longitude"), with: "-70.84"
    click_button I18n.t("app.fields.new.next")
    # The value goes wrong behind the person's back (an autofill, an edited page): the send must not be silent.
    page.execute_script("document.querySelector('input[name=\"field[longitude]\"]').value = '-708476706'")
    page.execute_script("document.querySelector('form.field-wizard').requestSubmit()")

    expect(page).to have_css(".toast--error", text: I18n.t("app.fields.new.invalid_step"))
    expect(page).to have_css(".field-wizard__step--current input[name='field[longitude]']")
    expect(user.farms.first.fields.count).to eq(1) # nothing new was saved
  end
end
