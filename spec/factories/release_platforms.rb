FactoryBot.define do
  factory :release_platform do
    train { association :train }
    app { train.app }
    name { "train" }
    platform { "android" }

    after(:build) do |release_platform|
      config_map = {
        release_platform:,
        workflows: {
          internal: nil,
          release_candidate: {
            kind: "release_candidate",
            name: Faker::FunnyName.name,
            id: Faker::Number.number(digits: 8),
            artifact_name_pattern: nil
          }
        },
        internal_release: nil,
        beta_release: {
          auto_promote: false,
          submissions: []
        }
      }
      config_map[:production_release] = ReleasePlatform::DEFAULT_PROD_RELEASE_CONFIG[release_platform.platform.to_sym]
      config_map[:production_release][:submissions].each do |submission|
        submission[:integrable_id] = release_platform.app.id
        submission[:integrable_type] = "App"
      end

      release_platform.platform_config = Config::ReleasePlatform.from_json(config_map)
    end
  end
end
