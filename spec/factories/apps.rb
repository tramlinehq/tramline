FactoryBot.define do
  factory :app do
    timezone { "Asia/Kolkata" }
    organization
    name { Faker::App.name }
    bundle_identifier { "com.example.com" }
    build_number { Faker::Number.number(digits: 4) }
    platform { "android" }

    after(:create) do |app, _|
      create(:integration, category: "version_control", providable: create(:github_integration), app:)
      create(:integration, category: "ci_cd", providable: create(:github_integration), app:)
    end

    after(:build) do |app, _|
      app.config = build(:app_config, app: app)
    end
  end
end
