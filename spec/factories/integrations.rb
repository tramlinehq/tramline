FactoryBot.define do
  factory :integration do
    association :app, factory: [:app, :android]
    association :providable, factory: :github_integration
    category { "version_control" }

    trait :with_google_play_store do
      association :app, factory: [:app, :android]
      association :providable, factory: [:google_play_store_integration, :without_callbacks_and_validations]
      category { "build_channel" }
    end

    trait :with_slack do
      association :providable, factory: [:slack_integration, :without_callbacks_and_validations]
      category { "build_channel" }
    end

    trait :with_app_store do
      association :app, factory: [:app, :ios]
      association :providable, factory: [:app_store_integration, :without_callbacks_and_validations]
      category { "build_channel" }
    end
  end
end
