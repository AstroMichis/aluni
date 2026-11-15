FactoryBot.define do
  factory :field_observation do
    field
    source { "nasa_power" }
    status { :ok }
    fetched_at { Time.current }
    payload { {} }
  end
end
