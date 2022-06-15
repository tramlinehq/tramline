FactoryBot.define do
  factory :sign_off_group_membership do
    sign_off_group
    association :user, factory: 'accounts_user'
  end
end
