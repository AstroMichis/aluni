require "rails_helper"

RSpec.describe "The main menu's ways around", type: :request do
  let(:user) { create(:user, display_name: "Ana") }
  let!(:field) { create_farm_for(user) }

  before { sign_in_as(user) }

  it "keeps every account tool in plain sight, with no folded menu" do
    get app_root_path(locale: "es"), headers: native_headers

    expect(response.body).not_to include("<details")
    expect(response.body).to include('class="dial-page__tools"')
    expect(response.body).to include(%(aria-label="#{I18n.t('layouts.passkeys', locale: :es)}")).and include(%(href="/es/passkeys"))
    expect(response.body).to include(%(aria-label="#{I18n.t('layouts.sign_out', locale: :es)}"))
    expect(response.body).to include(I18n.t("shared.ask_aluni.open", app_name: I18n.t("app_name"), locale: :es)).and include(%(src="/es/app/onboarding"))
  end

  it "steps through the sections with arrows and a dot each, the selected one marked" do
    get app_root_path(locale: "en", section: "weather"), headers: native_headers

    expect(response.body).to include(I18n.t("app.home.show.previous")).and include(I18n.t("app.home.show.next"))
    dots = response.body.scan(/<button[^>]*class="dial-steps__dot"[^>]*>/m)
    expect(dots.size).to eq(MenuHelper::SECTIONS.size)
    expect(dots.grep(/aria-current=true/).join).to include('data-tone="weather"')
    expect(response.body).to include(I18n.t("app.home.show.go_to", title: I18n.t("app.home.show.sections.crops.title")))
  end

  it "puts a count on My fields when the sources have something to confirm" do
    get app_root_path(locale: "en"), headers: native_headers

    expect(response.body).to include('class="dial__badge"')
    expect(response.body).to match(/\d+ things? to review/)
  end
end
