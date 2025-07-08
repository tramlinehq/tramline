FactoryBot.define do
  factory :gitlab_integration do
    oauth_access_token { Faker::Lorem.sentence }
  end
end
