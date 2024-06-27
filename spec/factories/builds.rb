FactoryBot.define do
  factory :build do
    sequence(:build_number) { |n| 123 + n }
    sequence(:version_name) { |n| "1.1.#{n}-dev" }
    association :workflow_run
    release_platform_run { workflow_run.release_platform_run }
    commit { workflow_run.commit }
    generated_at { Time.current }
  end
end
