FactoryBot.define do
  factory :platform_switch do
    service { "gemini" }
    paused { true }
    paused_by { "operator" }
    reason { "spec" }
  end
end
