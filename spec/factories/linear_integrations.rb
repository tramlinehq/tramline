FactoryBot.define do
  factory :linear_integration do
    oauth_access_token { "test_access_token" }
    oauth_refresh_token { "test_refresh_token" }
    organization_id { "test_org_id" }
  end
end
