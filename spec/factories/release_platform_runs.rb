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
            {number: 1,
             submission_type: "TestFlightSubmission",
             submission_config: {id: Faker::FunnyName.name, name: Faker::FunnyName.name, is_internal: true}}
          ]
        },
        production_release: {
          auto_promote: false,
          submissions: [
            {number: 1,
             submission_type: "AppStoreSubmission",
             submission_config: AppStoreIntegration::PROD_CHANNEL,
             rollout_config: {enabled: true, stages: AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE},
             auto_promote: false}
          ]
        }
      }
    }

    trait :created do
      status { "created" }
    end

    trait :on_track do
      status { "on_track" }
    end

    trait :post_release_started do
      status { "post_release_started" }
    end
  end
end
