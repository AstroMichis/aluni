# frozen_string_literal: true

require "webauthn/fake_client"

# A software authenticator for request specs. The origin must match
# config.x.webauthn.allowed_origins in test (http://www.example.com).
#
#   client = fake_authenticator
#   credential = client.create(challenge: options["challenge"], user_verified: true)
#   assertion  = client.get(challenge: options["challenge"], user_verified: true,
#                           user_handle: WebAuthn.standard_encoder.decode(user.webauthn_id))
module PasskeyHelpers
  FAKE_ORIGIN = "http://www.example.com"

  def fake_authenticator
    WebAuthn::FakeClient.new(FAKE_ORIGIN)
  end
end

RSpec.configure do |config|
  config.include PasskeyHelpers, type: :request
end
