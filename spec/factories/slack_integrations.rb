FactoryBot.define do
  factory :slack_integration do
    trait :without_callbacks_and_validations do
      after(:build) do |integration|
        def integration.complete_access = true
      end
    end
  end
end
