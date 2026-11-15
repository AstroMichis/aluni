require "rails_helper"

RSpec.describe "Ask Aluni from any screen", type: :system do
  include Result::Mixin

  let(:user) { create(:user, display_name: "Ana") }
  let!(:field) { create_farm_for(user) }

  before do
    driven_by_cuprite
    browser_sign_in(user)
  end

  it "opens the chat in place on a section screen and answers there" do
    allow(Onboarding::ReplyService).to receive(:call).and_return(Success(
      user_text: "What should follow corn?", assistant_text: "A legume such as soybeans breaks the pest cycle.",
      transition: nil, topic: "crops", topic_complete: false, proposal: nil, applied: nil, completed: false
    ))
    visit app_crops_path(locale: "en")
    expect(page).to have_no_css("#onboarding-messages")

    click_button I18n.t("shared.ask_aluni.open", app_name: I18n.t("app_name"))
    within("dialog.ask__panel") do
      expect(page).to have_css("#onboarding-messages", text: I18n.t("onboarding.welcome_message", name: "Ana").first(20), wait: 5)
      find("textarea[name='text']").fill_in(with: "What should follow corn?")
      find("button.chat__send").click
      expect(page).to have_content("A legume such as soybeans breaks the pest cycle.", wait: 5)
    end
    expect(page).to have_current_path(app_crops_path(locale: "en"))

    find("button.ask__close").click
    expect(page).to have_no_css("dialog.ask__panel[open]")
    expect_no_server_errors!
  end
end
