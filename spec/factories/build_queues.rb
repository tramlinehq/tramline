FactoryBot.define do
  factory :build_queue do
    release { association :release }
    scheduled_at { "2022-06-21 20:20:21" }
    is_active { true }
  end
end
