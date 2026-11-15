require "rails_helper"

RSpec.describe "Mascot", type: :request do
  let(:greeting) { ERB::Util.html_escape(I18n.t("mascot.greeting", app_name: I18n.t("app_name"))) }

  it "stands on the landing page with its greeting and its SVG twin" do
    get "/en"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="mascot"').and include('data-mascot-mode-value="landing"')
    expect(response.body).to include('data-mascot-dock-selector-value="#landing-chat-companion"')
    expect(response.body).to include(greeting).and include(I18n.t("mascot.question"))
    expect(response.body).to include(ERB::Util.html_escape(I18n.t("mascot.lets_go"))).and include(ERB::Util.html_escape(I18n.t("mascot.show_me_around")))
    expect(response.body).to include('class="mascot-avatar mascot-avatar--xl"')
    expect(response.body).to include(%(aria-label="#{ERB::Util.html_escape(I18n.t('mascot.avatar_label', app_name: I18n.t('app_name')))}"))
  end

  it "greets in Spanish under /es" do
    get "/es"

    expect(response.body).to include(ERB::Util.html_escape(I18n.t("mascot.greeting", app_name: I18n.t("app_name"), locale: :es)))
    expect(response.body).to include(I18n.t("mascot.question", locale: :es))
  end

  it "keeps the primary action for open sign-ups" do
    allow(Platform::Features).to receive(:signups_enabled?).and_return(false)

    get "/en"

    expect(response.body).to include('data-controller="mascot"')
    expect(response.body).not_to include('data-action="mascot#letsGo"')
    expect(response.body).to include('data-action="mascot#dismiss"')
  end

  it "stays off the native shells" do
    get "/en", headers: native_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('data-controller="mascot"')
  end

  it "renders the docked companion without a bubble" do
    html = ApplicationController.render(partial: "shared/mascot_companion")

    expect(html).to include('data-controller="mascot"').and include('data-mascot-mode-value="docked"')
    expect(html).to include('class="mascot-avatar mascot-avatar--lg"')
    expect(html).not_to include('data-mascot-target="bubble"')
  end
end
