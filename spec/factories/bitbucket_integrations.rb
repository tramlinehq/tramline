FactoryBot.define do
  factory :bitbucket_integration do
    oauth_access_token { Faker::Lorem.sentence }

    trait :without_callbacks_and_validations do
      to_create { |instance| instance.save(validate: false) }
      after(:build) do |integration|
        def integration.complete_access = nil
      end
    end
  end
end
