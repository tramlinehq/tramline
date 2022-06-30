FactoryBot.define do
  factory :accounts_user, class: "Accounts::User" do
    email { Faker::Internet.email }
    password { "this is strong password" }
    full_name { Faker::Name.name }
  end
end
