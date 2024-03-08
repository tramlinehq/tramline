FactoryBot.define do
  factory :deployment_run do
    association :step_run, factory: [:step_run, :with_build_artifact, :deployment_started]
    deployment { association :deployment, step: step_run.step }
    status { "created" }
    scheduled_at { Time.current }

    trait :created do
      status { "created" }
    end

    trait :started do
      status { "started" }
    end

    trait :preparing_release do
      status { "preparing_release" }
    end

    trait :prepared_release do
      status { "prepared_release" }
    end

    trait :submitted_for_review do
      status { "submitted_for_review" }
    end

    trait :review_failed do
      status { "review_failed" }
    end

    trait :ready_to_release do
      status { "ready_to_release" }
    end

    trait :uploaded do
      status { "uploaded" }
    end

    trait :released do
      status { "released" }
    end

    trait :failed do
      status { "failed" }
    end

    trait :rollout_started do
      status { "rollout_started" }
    end

    trait :with_external_release do
      after(:create) do |deployment_run, _|
        create(:external_release, deployment_run: deployment_run)
      end
    end

    trait :with_staged_rollout do
      association :step_run, factory: [:step_run, :with_release_step, :with_build_artifact, :deployment_started]
      deployment { association :deployment, :with_staged_rollout, :with_google_play_store, step: step_run.step }
    end

    trait :with_google_play_store do
      deployment { association :deployment, :with_google_play_store, step: step_run.step }
    end

    trait :with_slack do
      deployment { association :deployment, :with_slack, step: step_run.step }
    end
  end
end

def create_deployment_run_tree(platform, *traits, deployment_traits: [], step_traits: [:review], step_run_traits: [:deployment_started], train_traits: [], release_traits: [])
  create_deployment_tree(platform, *deployment_traits, step_traits:, train_traits: ) => { app:, train:, release_platform:, step:, deployment: }
  release = create(:release, *release_traits, train:)
  release_platform_run = create(:release_platform_run, release_platform:, release:)
  step_run = create(:step_run, *step_run_traits, step:, release_platform_run:)
  deployment_run = create(:deployment_run, *traits, deployment:, step_run:)
  { app:, train:, release_platform:, step:, deployment:, release:, release_platform_run:, step_run:, deployment_run: }
end
