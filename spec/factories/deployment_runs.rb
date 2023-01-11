FactoryBot.define do
  factory :deployment_run do
    # FIXME: steps are diverging here
    association :deployment, factory: [:deployment, :with_step]
    association :step_run, factory: [:releases_step_run, :with_build_artifact, :deployment_started]
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

    trait :with_google_play_store do
      association :deployment, factory: [:deployment, :with_step, :with_google_play_store]
    end

    trait :with_slack do
      association :deployment, factory: [:deployment, :with_step, :with_slack]
    end
  end
end
