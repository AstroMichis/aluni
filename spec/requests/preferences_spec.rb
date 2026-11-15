require "rails_helper"

RSpec.describe "Preferences", type: :request do
  def saved_preferences
    Preferences.from_cookie(CGI.unescape(cookies[Preferences::COOKIE.to_s].to_s))
  end

  it "saves allowlisted choices in the cookie and marks the intro done only when told" do
    post preferences_path(locale: "en"), params: { text_size: "large", motion: "reduce", read_aloud: "true", contrast: "bogus" },
                                         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:no_content)
    prefs = saved_preferences
    expect(prefs["text_size"]).to eq("large")
    expect(prefs["motion"]).to eq("reduce")
    expect(prefs["contrast"]).to eq("normal")
    expect(prefs).to be_read_aloud
    expect(prefs).not_to be_seen_welcome

    post preferences_path(locale: "en"), params: { done: "1" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(saved_preferences).to be_seen_welcome
    expect(saved_preferences["text_size"]).to eq("large")
  end

  it "renders the next page with the saved attributes and without the intro" do
    post preferences_path(locale: "en"), params: { text_size: "larger", theme: "light", contrast: "high", done: "1" }
    get "/en"

    expect(response.body).to include(%(data-text-size="larger")).and include(%(data-theme="light")).and include(%(data-contrast="high"))
    expect(response.body).to include(%(data-preferences-text-size-value="larger"))
    expect(response.body).not_to include(%(data-controller="intro"))
  end

  it "changes the language and goes back where the person was" do
    post preferences_path(locale: "en"), params: { preferred_locale: "es" }, headers: { "HTTP_REFERER" => "http://www.example.com/en?x=1" }

    expect(response).to redirect_to("/es?x=1")
    expect(cookies["locale"]).to eq("es")
    follow_redirect!
    expect(response.body).to include(%(lang="es"))
  end

  it "keeps a signed-in person's choices on the account and in the cookie" do
    user = create(:user)
    sign_in_as(user)

    post preferences_path(locale: "en"), params: { theme: "light", read_aloud: "true" }

    expect(user.reload.preferences).to include("theme" => "light", "read_aloud" => true)
    expect(saved_preferences["theme"]).to eq("light")
  end

  it "answers a plain form with a redirect back" do
    post preferences_path(locale: "en"), params: { theme: "light" }, headers: { "HTTP_REFERER" => "http://www.example.com/en" }

    expect(response).to redirect_to("http://www.example.com/en")
  end

  it "ignores a hand-edited cookie" do
    cookies[Preferences::COOKIE.to_s] = %q({"theme":"<script>","text_size":"huge","read_aloud":"yes","seen_welcome":true})
    get "/en"

    expect(response.body).to include(%(data-theme="dark")).and include(%(data-text-size="normal"))
    expect(response.body).not_to include(%(data-controller="intro"))
  end
end
