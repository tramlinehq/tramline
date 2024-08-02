FactoryBot.define do
  factory :organization, class: "Accounts::Organization" do
    name { "MyString" }
    status { "active" }
    created_by { "John Doe" }
    api_key { Faker::Lorem.word }

    trait :with_sso do
      sso { true }
      sso_domains { [Faker::Lorem.word + ".com"] }
      sso_tenant_id { Faker::String.random(length: 10) }
    end
  end
end
