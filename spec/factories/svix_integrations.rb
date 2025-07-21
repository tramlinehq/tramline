FactoryBot.define do
  factory :svix_integration do
    app_id { "app_#{SecureRandom.hex(8)}" }
    app_name { "Test Svix App" }
    status { "active" }

    trait :inactive do
      status { "inactive" }
    end

    trait :with_integration do
      after(:create) do |svix_integration|
        create(:integration, providable: svix_integration, category: :webhook)
      end
    end
  end
end
