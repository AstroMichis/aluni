require "rails_helper"

# The scripted landing chat in a real browser: the mascot's "Let's go" opens the
# panel, a name and a language are collected, and the passkey step is reached
# with the hidden fields filled. The ceremony itself needs a real authenticator
# and stays manual.
RSpec.describe "Landing chat", type: :system do
  before { driven_by(:cuprite) }

  it "collects a name and a language, then reaches the passkey step" do
    visit root_path(locale: "en")
    expect(page).to have_css(".landing__hero-content--visible", wait: 5)
    expect(page).to have_css("#landing-chat", visible: :hidden)

    page.execute_script("window.dispatchEvent(new CustomEvent('mascot:lets-go'))")

    expect(page).to have_css("#landing-chat:not([hidden])", wait: 5)
    expect(page).to have_content(I18n.t("landing_chat.script.ask_name"))

    fill_in "landing-chat-name", with: "Ana"
    click_button I18n.t("landing_chat.script.name_submit")

    expect(page).to have_content(I18n.t("landing_chat.script.nice_to_meet", name: "Ana"))
    expect(page).to have_content(I18n.t("landing_chat.script.ask_language"))

    click_button I18n.t("landing_chat.script.spanish")

    expect(page).to have_content(I18n.t("landing_chat.script.ask_passkey", locale: :es))
    expect(page).to have_button(I18n.t("landing_chat.script.create_passkey", locale: :es), disabled: :all)
    expect(page).to have_css("#landing-chat[lang='es']")
    expect(find("#landing-chat input[name='display_name']", visible: :hidden).value).to eq("Ana")
    expect(find("#landing-chat input[name='locale']", visible: :hidden).value).to eq("es")

    expect_no_server_errors!
  end

  it "resumes the step and the name after a reload and closes on request" do
    visit root_path(locale: "en")
    expect(page).to have_css(".landing__hero-content--visible", wait: 5)
    page.execute_script("window.dispatchEvent(new CustomEvent('mascot:lets-go'))")
    expect(page).to have_css("#landing-chat:not([hidden])", wait: 5)
    fill_in "landing-chat-name", with: "Ana"
    click_button I18n.t("landing_chat.script.name_submit")
    expect(page).to have_content(I18n.t("landing_chat.script.ask_language"))

    visit root_path(locale: "en")

    expect(page).to have_css("#landing-chat:not([hidden])", wait: 5)
    expect(page).to have_content(I18n.t("landing_chat.script.nice_to_meet", name: "Ana"))
    expect(page).to have_button(I18n.t("landing_chat.script.spanish"))

    find("#landing-chat button[data-action='landing-chat#close']").click
    expect(page).to have_css("#landing-chat", visible: :hidden)
    expect_no_server_errors!
  end
end
