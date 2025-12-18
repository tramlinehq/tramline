FactoryBot.define do
  factory :gitlab_integration do
    oauth_access_token { Faker::Lorem.sentence }
    oauth_refresh_token { Faker::Lorem.sentence }
    repository_config { {id: 123, full_name: "tramline/repo", namespace: "tramline"} }
    trait :without_callbacks_and_validations do
      to_create { |instance| instance.save(validate: false) }
      after(:build) do |integration|
        def integration.complete_access = nil

        def integration.correct_key = nil
      end
    end
  end
end
