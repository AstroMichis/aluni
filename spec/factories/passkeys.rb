FactoryBot.define do
  factory :passkey do
    user
    sequence(:external_id) { |n| WebAuthn.standard_encoder.encode("credential-#{n}") }
    public_key { WebAuthn.standard_encoder.encode("not-a-real-cose-key") }
    sign_count { 0 }
    nickname { "Phone" }
    transports { [ "internal" ] }
  end
end
