FactoryBot.define do
  factory :crashlytics_integration do
    integration { association :integration }
    json_key { '{"type": "service_account", "project_id": "test_project_id", "private_key_id": "1234abcd", "private_key": "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----\\n"}' }
    project_number { "1234567890" }

    trait :skip_validate_key do
      to_create { |instance| instance.save(validate: false) }
    end
  end
end
