FactoryBot.define do
  factory :field_crop do
    field
    crop_name { "Corn" }
    scientific_name { "Zea mays" }
    season_year { 2025 }
    planting_month { 4 }
    harvest_month { 10 }
    role { :main }
    source { :farmer }
  end
end
