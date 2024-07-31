FactoryBot.define do
  factory :invite, class: "Accounts::Invite" do
    association :organization
    association :sender, factory: :user
    email { Faker::Internet.email }
    role { "developer" }
  end
end
