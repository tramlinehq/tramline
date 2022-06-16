FactoryBot.define do
  factory :organization, class: "Accounts::Organization" do
    name { "MyString" }
    status { "active" }
    created_by { "John Doe" }
  end
end
