FactoryBot.define do
  factory :farmer_profile do
    user
    role { :owner }
    experience { :few_years }
    team { :family }
    units { :metric }
    goals { %w[rotation] }

    trait :blank do
      role { :unknown }
      experience { :unknown }
      team { :unknown }
      goals { [] }
    end
  end
end
