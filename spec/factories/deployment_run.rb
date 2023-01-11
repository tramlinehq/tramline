FactoryBot.define do
  factory :deployment_run do
    association :deployment, factory: [:deployment, :with_step]
    association :step_run, factory: :releases_step_run
    status { "created" }
    scheduled_at { Time.current }

    trait :started do
      status { "started" }
    end

    trait :uploaded do
      status { "uploaded" }
    end

    trait :released do
      status { "released" }
    end
  end
end
