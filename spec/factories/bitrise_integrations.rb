FactoryBot.define do
  factory :bitrise_integration do
    access_token { Faker::Lorem.sentence }

    trait :without_callbacks_and_validations do
      to_create { |instance| instance.save(validate: false) }
    end
  end
end
