FactoryBot.define do
  factory :teamcity_integration do
    server_url { "https://teamcity.example.com" }
    access_token { Faker::Lorem.sentence }

    trait :with_cloudflare do
      cf_access_client_id { "abc123.access" }
      cf_access_client_secret { "secret456" }
    end

    trait :without_callbacks_and_validations do
      to_create { |instance| instance.save(validate: false) }
      after(:build) do |integration|
        def integration.correct_key = true
      end
    end
  end
end
