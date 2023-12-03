FactoryBot.define do
  factory :app_variant do
    association :app_config
    name { Faker::Lorem.word }
    bundle_identifier { "com.example.com" }
  end
end
