FactoryBot.define do
  factory :app do
    timezone { "Asia/Kolkata" }
    organization
    name { Faker::App.name }
    bundle_identifier { "com.example.com" }
    build_number { Faker::Number.number(digits: 4) }
    # association :config, factory: :app_config
  end
end
