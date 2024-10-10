FactoryBot.define do
  factory :integration do
    integrable factory: %i[app android]
    providable factory: %i[google_firebase_integration without_callbacks_and_validations]
    category { "build_channel" }

    trait :with_google_play_store do
      integrable factory: %i[app android]
      providable factory: %i[google_play_store_integration without_callbacks_and_validations]
      category { "build_channel" }
    end

    trait :with_google_firebase do
      providable factory: %i[google_firebase_integration without_callbacks_and_validations]
      category { "build_channel" }
    end

    trait :with_slack do
      providable factory: %i[slack_integration without_callbacks_and_validations]
      category { "build_channel" }
    end

    trait :with_app_store do
      integrable factory: %i[app ios]
      providable factory: %i[app_store_integration without_callbacks_and_validations]
      category { "build_channel" }
    end

    trait :notification do
      providable factory: %i[slack_integration without_callbacks_and_validations]
      category { "notification" }
    end
  end
end
