FactoryBot.define do
  factory :sso_authentication, class: "Accounts::SsoAuthentication" do
    email { Faker::Internet.email }
  end
end
