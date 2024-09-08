FactoryBot.define do
  factory :app_variant do
    app_config
    name { Faker::Lorem.word }
    bundle_identifier { "com.example.com" }
  end
end
