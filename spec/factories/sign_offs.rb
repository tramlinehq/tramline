FactoryBot.define do
  factory :sign_off do
    sign_off_group
    association :step, factory: :releases_step
    association :user, factory: :accounts_user
  end
end
