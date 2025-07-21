FactoryBot.define do
  factory :svix_integration do
    train
    app_id { "app_#{SecureRandom.hex(8)}" }
    app_name { "Test Svix App" }
    status { "active" }

    trait :inactive do
      status { "inactive" }
    end

    trait :without_app_id do
      app_id { nil }
    end

    trait :with_app_name do
      app_name { "Custom Svix App" }
    end
  end
end
