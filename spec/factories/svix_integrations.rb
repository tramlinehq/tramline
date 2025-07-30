FactoryBot.define do
  factory :webhook_integration, class: "SvixIntegration" do
    train
    svix_app_id { "app_#{SecureRandom.hex(8)}" }
    svix_app_name { "Test Svix App" }
    status { "active" }

    trait :inactive do
      status { "inactive" }
    end

    trait :without_app_id do
      svix_app_id { nil }
    end

    trait :with_app_name do
      svix_app_name { "Custom Svix App" }
    end
  end
end
