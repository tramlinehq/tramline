FactoryBot.define do
  factory :invite, class: "Accounts::Invite" do
    organization
    sender factory: %i[user]
    email { Faker::Internet.email }
    role { "developer" }
  end
end
