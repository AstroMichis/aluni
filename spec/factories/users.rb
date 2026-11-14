FactoryBot.define do
  factory :user do
    display_name { Faker::Name.first_name }
    locale { "en" }

    trait :with_email do
      sequence(:email_address) { |n| "person#{n}@example.com" }
    end

    trait :spanish do
      locale { "es" }
    end
  end
end
