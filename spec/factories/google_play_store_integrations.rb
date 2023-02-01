FactoryBot.define do
  factory :google_play_store_integration do
    json_key { Faker::Json.shallow_json(width: 1) }

    trait :without_callbacks_and_validations do
      to_create { |instance| instance.save(validate: false, callback: false) }

      after(:build) do |integration|
        def integration.create_external_app
        end
      end
    end
  end
end
