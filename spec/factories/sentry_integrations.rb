FactoryBot.define do
  factory :sentry_integration do
    integration { association :integration }
    access_token { "sntrys_test_token_1234567890abcdef" }

    trait :with_ios_config do
      ios_config do
        {
          project: {
            id: "123456",
            slug: "test-ios-project",
            name: "Test iOS Project"
          },
          environment: "production",
          organization_slug: "test-org"
        }
      end
    end

    trait :with_android_config do
      android_config do
        {
          project: {
            id: "789012",
            slug: "test-android-project",
            name: "Test Android Project"
          },
          environment: "production",
          organization_slug: "test-org"
        }
      end
    end

    trait :skip_validate do
      to_create { |instance| instance.save(validate: false) }
    end
  end
end
