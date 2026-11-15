FactoryBot.define do
  factory :field do
    farm
    name { "North field" }
    latitude { 42.0 }
    longitude { -93.75 }
    location_confidence { :confirmed }
    location_source { :geolocation }
    area { 12.5 }
    area_unit { :hectares }
    irrigation { :rainfed }
    water_source { :rain }

    trait :unlocated do
      latitude { nil }
      longitude { nil }
      location_confidence { :unknown }
      location_source { :unknown }
    end
  end
end
