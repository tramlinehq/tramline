FactoryBot.define do
  factory :deployment do
    sequence(:build_artifact_channel) { |n| {id: n} }
    association :integration

    trait :with_step do
      before(:create) do |deployment, _|
        train = create(:train, app: deployment.integration.app)
        release_platform = create(:release_platform, train: train)
        build(:step, release_platform: release_platform)
          .tap { |step| step.deployments << deployment }
          .save
      end
    end

    trait :with_release_step do
      before(:create) do |deployment, _|
        train = create(:train, app: deployment.integration.app)
        release_platform = create(:release_platform, train: train)
        build(:step, :release, release_platform: release_platform)
          .tap { |step| step.deployments << deployment }
          .save
      end
    end

    trait :with_production_channel do
      build_artifact_channel { {is_production: true} }
    end

    trait :with_google_play_store do
      association :integration, :with_google_play_store
    end

    trait :with_slack do
      association :integration, :with_slack
    end

    trait :with_app_store do
      association :integration, :with_app_store
    end

    trait :with_external do
      build_artifact_channel { {"id" => "external", "name" => "External"} }
      integration { nil }
    end

    trait :with_phased_release do
      build_artifact_channel { {is_production: true} }
      is_staged_rollout { true }
    end

    trait :with_staged_rollout do
      build_artifact_channel { {is_production: true} }
      is_staged_rollout { true }
      staged_rollout_config { [1, 100] }
    end
  end
end
