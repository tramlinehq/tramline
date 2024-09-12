FactoryBot.define do
  factory :staged_rollout do
    deployment_run

    config { [1, 100] }
    current_stage { nil }

    trait :started do
      status { "started" }
    end

    trait :paused do
      status { "paused" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :stopped do
      status { "stopped" }
    end
  end
end
