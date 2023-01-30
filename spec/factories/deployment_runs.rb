FactoryBot.define do
  factory :deployment_run do
    association :step_run, factory: [:releases_step_run, :with_build_artifact, :deployment_started]
    deployment { association :deployment, step: step_run.step }
    status { "created" }
    scheduled_at { Time.current }

    trait :started do
      status { "started" }
    end

    trait :submitted do
      status { "submitted" }
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

    trait :with_google_play_store do
      deployment { association :deployment, :with_google_play_store, step: step_run.step }
    end

    trait :with_slack do
      deployment { association :deployment, :with_slack, step: step_run.step }
    end

    trait :with_app_store do
      deployment { association :deployment, :with_app_store, step: step_run.step }
    end
  end
end

def create_deployment_run_for_ios(trait)
  app = create(:app, :ios)
  train = create(:releases_train, app: app)
  step = create(:releases_step, :with_deployment, train: train)
  deployment = create(:deployment, integration: train.build_channel_integrations.first, step: step)
  step_run = create(:releases_step_run, :deployment_started, step: step)
  create(:deployment_run, trait, deployment: deployment, step_run: step_run)
end
