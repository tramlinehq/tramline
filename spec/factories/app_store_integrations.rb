FactoryBot.define do
  factory :app_store_integration do
    trait :without_callbacks_and_validations do
      to_create { |instance| instance.save(validate: false) }
    end
  end
end
