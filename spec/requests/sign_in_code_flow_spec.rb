require "rails_helper"

# Sign-in and sign-up with a code sent by email, end to end over HTTP: the
# same answer for every address, the code read back from the delivered mail,
# the attempts, the link, the account creation with the finder's field.
RSpec.describe "Sign-in codes", type: :request do
  before { ActionMailer::Base.deliveries.clear }

  def last_code = ActionMailer::Base.deliveries.last.text_part.decoded[/\b(\d{3}) (\d{3})\b/].delete(" ")
  def last_token = CGI.unescape(ActionMailer::Base.deliveries.last.text_part.decoded[/token=([^\s&]+)/, 1])

  def request_code!(email, extra = {})
    post sign_in_code_path(locale: "en"), params: { email: email, mode: "sign_in" }.merge(extra), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include('target="auth"')
  end

  it "answers a known and an unknown address alike and mails a code with a link" do
    create(:user, :with_email, email_address: "known@example.com")

    request_code!("known@example.com")
    known = response.body
    request_code!("nobody@example.com")

    expect(response.body.gsub(/\b[a-z]\*\*\*@/, "x***@")).to eq(known.gsub(/\b[a-z]\*\*\*@/, "x***@"))
    expect(ActionMailer::Base.deliveries.size).to eq(2)
    expect(ActionMailer::Base.deliveries.last.subject).to include(last_code[0, 3])
    expect(session[:sign_in_code_id]).to be_present
  end

  it "signs an existing person in with the right code and records the method" do
    user = create(:user, :with_email, email_address: "ana@example.com")
    request_code!("ana@example.com")

    post verify_sign_in_code_path(locale: "en"), params: { code: "#{last_code[0, 3]} #{last_code[3, 3]}", mode: "sign_in" }

    expect(response).to redirect_to(app_root_url(locale: "en"))
    expect(user.sessions.last.sign_in_method).to eq("email_code")
    expect(user.reload.email_verified_at).to be_present
    expect(flash[:suggest_passkey]).to be(true)

    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  it "counts wrong codes as a stream, then gives up" do
    create(:user, :with_email, email_address: "ana@example.com")
    request_code!("ana@example.com")

    post verify_sign_in_code_path(locale: "en"), params: { code: "000000", mode: "sign_in" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include('target="auth"')

    4.times { post verify_sign_in_code_path(locale: "en"), params: { code: "000000", mode: "sign_in" } }
    post verify_sign_in_code_path(locale: "en"), params: { code: last_code, mode: "sign_in" }
    expect(response).not_to redirect_to(app_root_url(locale: "en"))
    expect(Session.count).to eq(0)
  end

  it "creates the account from the finder's details and completes the setup" do
    request_code!("new@example.com", display_name: "Ana", locale: "es", mode: "finder",
                                     latitude: "42.0", longitude: "-93.75", place_label: "Near Ames", country_code: "US", admin_area: "Iowa",
                                     location_source: "map", crop_name: "Corn", irrigation: "rainfed", area: "12", area_unit: "acres")

    post verify_sign_in_code_path(locale: "en"), params: { code: last_code, mode: "finder" }

    expect(response).to redirect_to(app_root_url(locale: "en"))
    user = User.find_by!(email_address: "new@example.com")
    expect(user.display_name).to eq("Ana")
    expect(user.locale).to eq("es")
    expect(user.farms.first.fields.first.latitude).to eq(42.0)
    expect(user.farms.first.fields.first.field_crops.count).to eq(1)
    expect(user.onboarding_complete?).to be(true)
    expect(user.sessions.last.sign_in_method).to eq("email_code")
  end

  it "asks a newcomer from the sign-in page for a name, then creates the account" do
    request_code!("new@example.com")

    post verify_sign_in_code_path(locale: "en"), params: { code: last_code, mode: "sign_in" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("sign_in_codes.name.title"))

    post complete_sign_in_code_path(locale: "en"), params: { display_name: "Ana", mode: "sign_in" }
    expect(response).to redirect_to(app_root_url(locale: "en"))
    expect(User.find_by!(email_address: "new@example.com").display_name).to eq("Ana")
  end

  it "refuses a new account only after the code is proven while sign-ups are closed" do
    Rails.configuration.x.signups.enabled = false
    request_code!("new@example.com")
    expect(ActionMailer::Base.deliveries.size).to eq(1)

    post verify_sign_in_code_path(locale: "en"), params: { code: last_code, mode: "sign_in" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("sign_in_codes.choice.errors.signups_closed"))
    expect(User.count).to eq(0)
  ensure
    Rails.configuration.x.signups.enabled = true
  end

  it "signs in from the mail's link in the same browser and shows the code elsewhere" do
    create(:user, :with_email, email_address: "ana@example.com")
    request_code!("ana@example.com")
    token = last_token

    get sign_in_link_path(locale: "en", token: token)
    expect(response).to redirect_to(app_root_url(locale: "en"))
    expect(Session.count).to eq(1)

    ActionMailer::Base.deliveries.clear
    request_code!("ana@example.com")
    token = last_token
    code = last_code
    reset!
    get sign_in_link_path(locale: "en", token: token)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("#{code[0, 3]} #{code[3, 3]}").and include(I18n.t("sign_in_codes.link.title"))
    expect(Session.count).to eq(1)

    get sign_in_link_path(locale: "en", token: "nonsense")
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "resends only after the cooldown" do
    request_code!("ana@example.com")

    post resend_sign_in_code_path(locale: "en"), params: { mode: "sign_in" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response).to have_http_status(:ok)
    expect(ActionMailer::Base.deliveries.size).to eq(1)

    travel 61.seconds
    post resend_sign_in_code_path(locale: "en"), params: { mode: "sign_in" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(ActionMailer::Base.deliveries.size).to eq(2)
  end

  it "answers calmly when mail is paused or the address is malformed" do
    create(:platform_switch, service: "mail", paused: true)
    post sign_in_code_path(locale: "en"), params: { email: "ana@example.com", mode: "sign_in" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("sign_in_codes.choice.errors.unavailable"))

    PlatformSwitch.delete_all
    Platform::Switchboard.bust!
    post sign_in_code_path(locale: "en"), params: { email: "nope", mode: "sign_in" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response.body).to include(I18n.t("sign_in_codes.choice.errors.invalid_email"))
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "renders the full page, in Spanish too, and stays behind the web kill switch" do
    get sign_in_code_path(locale: "es")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="auth"').and include(I18n.t("sign_in_codes.choice.email_title", locale: :es))

    get sign_in_code_path(locale: "en"), headers: native_headers
    expect(response).to have_http_status(:ok)

    with_native_web_access(false) { get sign_in_code_path(locale: "en") }
    expect(response).to redirect_to(root_path(locale: "en"))
  end
end
