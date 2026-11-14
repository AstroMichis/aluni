# frozen_string_literal: true

# Request-spec helpers for the passkey/session layer.
#
#   get app_root_path, headers: native_headers        # as the native shell
#   sign_in_as(user)                                   # sets the signed session cookie
#   post sign_in_path, params: {...}, headers: native_headers, as: :json
module AuthenticationHelpers
  # turbo-rails' hotwire_native_app? matches /(Turbo|Hotwire) Native/.
  NATIVE_USER_AGENT = "Aluni/1.0 Hotwire Native iOS; Turbo Native iOS"

  def native_headers(extra = {})
    { "HTTP_USER_AGENT" => NATIVE_USER_AGENT }.merge(extra)
  end

  # Opens a Session for the user and sets the signed cookie Authentication reads.
  def sign_in_as(user, user_agent: NATIVE_USER_AGENT)
    session = user.sessions.create!(user_agent: user_agent, ip_address: "127.0.0.1")
    ActionDispatch::TestRequest.create.cookie_jar.tap do |jar|
      jar.signed[:session_id] = session.id
      cookies[:session_id] = jar[:session_id]
    end
    session
  end

  # Flips the NATIVE_WEB_ACCESS flag for one block.
  def with_native_web_access(value)
    saved = Rails.configuration.x.native.web_access
    Rails.configuration.x.native.web_access = value
    yield
  ensure
    Rails.configuration.x.native.web_access = saved
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
end
