FactoryBot.define do
  factory :session do
    user
    ip_address { "127.0.0.1" }
    user_agent { "Aluni/1.0 Hotwire Native iOS; Turbo Native iOS" }
  end
end
