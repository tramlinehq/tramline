FactoryBot.define do
  factory :deployment_run do
    association :step_run, factory: [:releases_step_run, :with_build_artifact, :deployment_started]
    deployment { association :deployment, step: step_run.step }
    status { "created" }
    scheduled_at { Time.current }

    trait :created do
      status { "created" }
    end

    trait :started do
      status { "started" }
    end

    trait :prepared_release do
      status { "prepared_release" }
    end

    trait :submitted_for_review do
      status { "submitted_for_review" }
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
      association :step_run, factory: [:releases_step_run, :with_release_step, :with_build_artifact, :deployment_started]
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

def create_deployment_run_for_ios(*traits, deployment_traits: [], step_trait: :review, step_run_trait: :deployment_started)
  app = create(:app, :ios)
  train = create(:releases_train, app: app)
  step = create(:releases_step, :with_deployment, step_trait, train: train)
  deployment = create(:deployment, *deployment_traits, integration: train.build_channel_integrations.first, step: step)
  step_run = create(:releases_step_run, step_run_trait, step: step)
  create(:deployment_run, *traits, deployment: deployment, step_run: step_run)
end
