FactoryBot.define do
  factory :google_firebase_integration do
    trait :without_callbacks_and_validations do
      after(:build) do |integration|
        def integration.correct_key = true
      end
    end
  end
end
