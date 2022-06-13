FactoryBot.define do
  factory :sign_off_group do
    name { "production" }
    app
    approved { false }
  end
end
