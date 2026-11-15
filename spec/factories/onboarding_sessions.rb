FactoryBot.define do
  factory :onboarding_session do
    user
    topic { "welcome" }
    language { "en" }

    trait :completed do
      status { :completed }
      completed_at { Time.current }
      topic { "summary" }
    end
  end
end
