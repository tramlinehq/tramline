FactoryBot.define do
  factory :linear_integration do
    oauth_access_token { "test_access_token" }
    oauth_refresh_token { "test_refresh_token" }
    workspace_id { "test_org_id" }
    workspace_name { "test_org" }
    workspace_url_key { "test" }
  end
end
