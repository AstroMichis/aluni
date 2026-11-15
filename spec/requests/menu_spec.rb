require "rails_helper"

RSpec.describe "Main menu dial", type: :request do
  it "renders the dial with every section and its panel in English" do
    get "/en/menu"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="radial-menu"').and include('role="slider"')
    expect(response.body.scan('data-radial-menu-target="sector"').size).to eq(MenuHelper::SECTIONS.size)
    expect(response.body.scan('data-radial-menu-target="panel"').size).to eq(MenuHelper::SECTIONS.size)

    MenuHelper::SECTIONS.each do |key, options|
      expect(response.body).to include(CGI.escapeHTML(I18n.t("pages.menu.sections.#{key}.title")))
      options.each do |option|
        expect(response.body).to include(CGI.escapeHTML(I18n.t("pages.menu.sections.#{key}.options.#{option}.title")))
      end
    end
    expect(response.body).to include(I18n.t("pages.menu.add_field"))
  end

  it "renders the dial in Spanish under /es" do
    get "/es/menu"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('lang="es"').and include(CGI.escapeHTML(I18n.t("pages.menu.headline", locale: :es)))
    expect(response.body).to include(I18n.t("pages.menu.sections.fields.title", locale: :es))
  end
end
