FactoryBot.define do
  factory :release_platform do
    train { association :train }
    app { train.app }
    name { "train" }
    platform { "android" }

    after(:build) do |release_platform|
      config = {
        workflows: {
          internal: nil,
          release_candidate: {
            name: Faker::FunnyName.name,
            id: Faker::Number.number(digits: 8),
            artifact_name_pattern: nil
          }
        },
        internal_release: nil,
        beta_release: nil,
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

      release_platform.platform_config = Config::ReleasePlatform.from_json(config)
    end
  end
end
