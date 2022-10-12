FactoryBot.define do
  factory :deployment_run do
    association :deployment, factory: :deployment
    association :step_run, factory: :releases_step_run
    status { "created" }
    scheduled_at { Time.current }
  end
end
