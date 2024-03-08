FactoryBot.define do
  factory :step_run do
    sequence(:build_number) { |n| 123 + n }
    sequence(:build_version) { |n| "1.1.#{n}-dev" }
    association :commit
    step { association :step, :with_deployment }
    release_platform_run { association :release_platform_run, release_platform: step.release_platform }
    scheduled_at { Time.current }
    status { "on_track" }

    trait :ci_workflow_triggered do
      status { "ci_workflow_triggered" }
    end

    trait :ci_workflow_started do
      status { "ci_workflow_started" }
    end

    trait :ci_workflow_failed do
      status { "ci_workflow_failed" }
    end

    trait :build_ready do
      status { "build_ready" }
    end

    trait :deployment_started do
      status { "deployment_started" }
    end

    trait :deployment_restarted do
      status { "deployment_restarted" }
    end

    trait :success do
      status { "success" }
    end

    trait :ci_workflow_unavailable do
      status { "ci_workflow_unavailable" }
    end

    trait :ci_workflow_halted do
      status { "ci_workflow_halted" }
    end

    trait :deployment_failed do
      status { "deployment_failed" }
    end

    trait :build_available do
      status { "build_available" }
    end

    trait :build_unavailable do
      status { "build_unavailable" }
    end

    trait :build_found_in_store do
      status { "build_found_in_store" }
    end

    trait :build_not_found_in_store do
      status { "build_not_found_in_store" }
    end

    trait :cancelling do
      status { "cancelling" }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :with_build_artifact do
      after(:create) do |step_run, _|
        create(:build_artifact, step_run: step_run)
      end
    end

    trait :with_release_step do
      association :step, factory: [:step, :release, :with_deployment]
    end
  end
end
