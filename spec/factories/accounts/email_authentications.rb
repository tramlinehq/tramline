FactoryBot.define do
  factory :email_authentication, class: "Accounts::EmailAuthentication" do
    email { Faker::Internet.email }
    password { "foo bar baz" }
    confirmed_at { Time.zone.now }
  end
end
