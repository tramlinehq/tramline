FactoryBot.define do
  factory :user, class: "Accounts::User" do
    email { Faker::Internet.email }
    password { Faker::Internet.password(min_length: 10, max_length: 20, mix_case: true, special_characters: true) }
    full_name { Faker::Name.name }

    trait :as_developer do
      transient do
        member_organization { create(:organization) }
      end

      after(:create) do |user, evaluator|
        create(:membership, :developer, user: user, organization: evaluator.member_organization)
      end
    end
  end
end
