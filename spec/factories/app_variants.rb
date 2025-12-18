FactoryBot.define do
  factory :app_variant do
    app factory: %i[app android]
    name { Faker::Lorem.word }
    bundle_identifier { "com.example.com" }
  end
end
