FactoryBot.define do
  factory :membership, class: "Accounts::Membership" do
    organization
    user
    role { "developer" }

    trait :owner do
      role { "owner" }
    end

    trait :viewer do
      role { "viewer" }
    end

    trait :developer do
      role { "developer" }
    end
  end
end
