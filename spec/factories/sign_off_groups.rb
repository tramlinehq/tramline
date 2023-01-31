FactoryBot.define do
  factory :sign_off_group do
    name { "production" }
    association :app, :android
  end
end
