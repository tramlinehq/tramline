FactoryBot.define do
  factory :release_platform_run do
    release_platform
    release { association :release }
    code_name { Faker::FunnyName.name }
    scheduled_at { Time.current }
    status { "on_track" }
    release_version { "1.2.3" }
    in_store_resubmission { false }
    config {
      {
        workflows: {
          internal: nil,
          release_candidate: {
            name: Faker::FunnyName.name,
            id: Faker::Number.number(digits: 8),
            artifact_name_pattern: nil
          }
        },
        internal_release: nil,
        beta_release: {
          auto_promote: false,
          submissions: [
            {
              number: 1,
              submission_type: "TestFlightSubmission",
              submission_config: {id: Faker::FunnyName.name, name: Faker::FunnyName.name, is_internal: true},
              integrable_id: release_platform.app.id,
              integrable_type: "App"
            }
          ]
        },
        production_release: {
          auto_promote: false,
          submissions: [
            {
              number: 1,
              submission_type: "AppStoreSubmission",
              submission_config: AppStoreIntegration::PROD_CHANNEL,
              rollout_config: {enabled: true, stages: AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE},
              auto_promote: false,
              integrable_id: release_platform.app.id,
              integrable_type: "App"
            }
          ]
        }
      }
    }

    trait :android do
      config {
        {
          workflows: {
            internal: nil,
            release_candidate: {
              name: Faker::FunnyName.name,
              id: Faker::Number.number(digits: 8),
              artifact_name_pattern: nil
            }
          },
          internal_release: nil,
          beta_release: {
            auto_promote: false,
            submissions: [
              {
                number: 1,
                submission_type: "PlayStoreSubmission",
                submission_config: {id: :internal, name: "internal testing"},
                rollout_config: {enabled: false},
                auto_promote: true,
                integrable_id: release_platform.app.id,
                integrable_type: "App"
              }
            ]
          },
          production_release: {
            auto_promote: false,
            submissions: [
              {
                number: 1,
                submission_type: "PlayStoreSubmission",
                submission_config: {
                  id: :production,
                  name: "production"
                },
                rollout_config: {
                  enabled: true,
                  stages: [1, 5, 10, 20, 50, 100]
                },
                finish_rollout_in_next_release: true,
                integrable_id: release_platform.app.id,
                integrable_type: "App"
              }
            ]
          }
        }
      }
    end

    trait :created do
      status { "created" }
    end

    trait :on_track do
      status { "on_track" }
    end

    trait :finished do
      status { "finished" }
    end

    trait :post_release_started do
      status { "post_release_started" }
    end
  end
end

def create_production_rollout_tree(train, release_platform, release_status: :finished, rollout_status: :completed, submission_status: :created, skip_rollout: false)
  release = create(:release, release_status, train:)
  platform = release_platform.platform
  release_platform_run = create(:release_platform_run, platform.to_sym, :finished, release_platform:, release:)
  parent_release = create(:production_release, :finished, config: release_platform_run.conf.production_release.as_json, release_platform_run:)
  store_submission = create(:play_store_submission, status: submission_status, config: parent_release.conf.submissions.first, parent_release:, release_platform_run:)

  unless skip_rollout
    config = store_submission.conf.rollout_stages
    store_rollout = create(:store_rollout, rollout_status, :play_store, config:, release_platform_run:, store_submission:)
  end

  {
    train: train,
    release: release,
    release_platform: release_platform,
    release_platform_run: release_platform_run,
    production_release: parent_release,
    store_submission: store_submission,
    store_rollout: store_rollout
  }
end
