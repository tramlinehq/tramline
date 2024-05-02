FactoryBot.define do
  factory :build do
    sequence(:build_number) { |n| 123 + n }
    sequence(:version_name) { |n| "1.1.#{n}-dev" }
    association :commit
    association :release_platform_run
    generated_at { Time.current }
  end
end
