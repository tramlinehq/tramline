FactoryBot.define do
  factory :codemagic_integration do
    access_token { Faker::Lorem.sentence }

    trait :without_callbacks_and_validations do
      to_create { |instance| instance.save(validate: false) }
      after(:build) do |integration|
        def integration.correct_key = true
      end
    end
  end
end
