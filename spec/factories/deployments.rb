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

    trait :with_google_play_store do
      association :integration, :with_google_play_store
    end

    trait :with_slack do
      association :integration, :with_slack
    end

    trait :with_app_store do
      association :integration, :with_app_store
    end
  end
end
