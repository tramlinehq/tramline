FactoryBot.define do
  factory :app_store_integration do
    trait :without_callbacks_and_validations do
      after(:build) do |integration|
        def integration.set_external_details_on_app = true
      end

      to_create { |instance| instance.save(validate: false) }
    end

    after(:build) do |integration|
      def integration.refresh_external_app = true
    end
  end
end
