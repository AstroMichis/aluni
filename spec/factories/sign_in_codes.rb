FactoryBot.define do
  factory :sign_in_code do
    channel { :email }
    destination { "ana@example.com" }
    transient { code { "123456" } }
    code_digest { Auth::Codes.digest(destination, code) }
    expires_at { SignInCode::TTL.from_now }
    locale { "en" }

    trait :expired do
      expires_at { 1.minute.ago }
    end

    trait :verified do
      consumed_at { Time.current }
      verified_at { Time.current }
    end
  end
end
