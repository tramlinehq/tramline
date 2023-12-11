FactoryBot.define do
  factory :organization, class: "Accounts::Organization" do
    name { "MyString" }
    status { "active" }
    created_by { "John Doe" }
    api_key { Faker::Lorem.word }
  end
end
