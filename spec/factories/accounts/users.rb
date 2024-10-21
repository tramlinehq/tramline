FactoryBot.define do
  factory :user, class: "Accounts::User" do
    full_name { Faker::Name.name }
    unique_authn_id { Faker::Internet.uuid }

    trait :as_owner do
      transient do
        member_organization { nil }
      end

      after(:create) do |user, evaluator|
        if evaluator.member_organization.nil?
          create(:membership, :owner, user:)
        else
          create(:membership, :owner, user:, organization: evaluator.member_organization)
        end

        create(:email_authentication, user:)
      end
    end

    trait :as_developer do
      transient do
        member_organization { nil }
      end

      after(:create) do |user, evaluator|
        if evaluator.member_organization.nil?
          create(:membership, :developer, user: user)
        else
          create(:membership, :developer, user: user, organization: evaluator.member_organization)
        end
      end
    end

    trait :with_email_authentication do
      after(:create) do |user|
        create(:email_authentication, user:)
      end
    end
  end
end
