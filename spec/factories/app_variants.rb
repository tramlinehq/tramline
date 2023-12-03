FactoryBot.define do
  factory :app_variant do
    association :app_config
    bundle_identifier { "com.example.com" }
  end
end
