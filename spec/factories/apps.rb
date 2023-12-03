FactoryBot.define do
  factory :app do
    timezone { "Asia/Kolkata" }
    organization
    name { Faker::App.name }
    bundle_identifier { "com.example.com" }
    build_number { Faker::Number.number(digits: 4) }

    trait :android do
      platform { "android" }
      after(:create) do |app, _|
        create(:integration, category: "version_control", providable: create(:github_integration), app:)
        create(:integration, category: "ci_cd", providable: create(:github_integration), app:)
        create(:integration, :with_google_play_store, app:)
      end
    end

    trait :ios do
      platform { "ios" }
      after(:create) do |app, _|
        create(:integration, category: "version_control", providable: create(:github_integration), app:)
        create(:integration, category: "ci_cd", providable: create(:bitrise_integration, :without_callbacks_and_validations), app:)
        create(:integration, :with_app_store, app:)
      end
    end

    trait :cross_platform do
      platform { "cross_platform" }
      after(:create) do |app, _|
        create(:integration, category: "version_control", providable: create(:github_integration), app:)
        create(:integration, category: "ci_cd", providable: create(:github_integration), app:)
        create(:integration, :with_google_play_store, app:)
        create(:integration, :with_app_store, app:)
      end
    end

    trait :with_valid_config do
      after(:build) do |app|
        app.config = build(:app_config, app: app)
      end
    end

    trait :without_config do
      after(:build) do |app|
        app.config = nil
      end
    end
  end
end
