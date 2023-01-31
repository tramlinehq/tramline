FactoryBot.define do
  factory :releases_step_run, class: "Releases::Step::Run" do
    sequence(:build_number) { |n| 123 + n }
    sequence(:build_version) { |n| "1.1.#{n}-dev" }
    association :commit, factory: :releases_commit
    association :step, factory: [:releases_step, :with_deployment]
    train_run { association :releases_train_run, train: step.train }
    scheduled_at { Time.current }
    status { "on_track" }

    trait :ci_workflow_failed do
      status { "ci_workflow_failed" }
    end

    trait :build_ready do
      status { "build_ready" }
    end

    trait :deployment_started do
      status { "deployment_started" }
    end

    trait :success do
      status { "success" }
    end

    trait :ci_workflow_unavailable do
      status { "ci_workflow_unavailable" }
    end

    trait :ci_workflow_failed do
      status { "ci_workflow_failed" }
    end

    trait :deployment_failed do
      status { "deployment_failed" }
    end

    trait :build_available do
      status { "build_available" }
    end

    trait :build_found_in_store do
      status { "build_found_in_store" }
    end

    trait :with_build_artifact do
      after(:create) do |step_run, _|
        create(:build_artifact, step_run: step_run)
      end
    end
  end
end

def create_step_run_for_ios(trait)
  app = create(:app, :ios)
  train = create(:releases_train, app: app)
  step = create(:releases_step, :with_deployment, train: train)
  create(:releases_step_run, trait, step: step)
end
