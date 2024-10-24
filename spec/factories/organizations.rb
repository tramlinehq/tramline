FactoryBot.define do
  factory :organization, class: "Accounts::Organization" do
    name { "MyString" }
    status { "active" }
    created_by { "John Doe" }
    api_key { Faker::Lorem.word }

    trait :with_sso do
      sso { true }
      sso_domains { [Faker::Lorem.word + ".com"] }
      sso_tenant_id { Faker::Lorem.word }
    end

    trait :with_owner_membership do
      after(:create) do |organization, _|
        create(:user, :as_owner, member_organization: organization)
      end
    end
  end
end
