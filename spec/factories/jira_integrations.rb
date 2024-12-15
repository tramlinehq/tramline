FactoryBot.define do
  factory :jira_integration do
    oauth_access_token { "test_access_token" }
    oauth_refresh_token { "test_refresh_token" }
    cloud_id { "cloud_123" }
    integration

    trait :with_app_config do
      after(:create) do |jira_integration|
        app = jira_integration.integration.integrable
        app.config.update!(jira_config: {
          "release_filters" => [
            {"type" => "label", "value" => "release-1.0"},
            {"type" => "fix_version", "value" => "v1.0.0"}
          ]
        })
      end
    end
  end
end
