FactoryBot.define do
  factory :deployment do
    sequence(:build_artifact_channel) { |n| {id: n} }

    trait :with_step do
      before(:create) do |deployment, _|
        build(:releases_step)
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

    trait :with_staged_rollout do
      build_artifact_channel { {is_production: true} }
      is_staged_rollout { true }
      staged_rollout_config { "1, 100" }
    end
  end
end
