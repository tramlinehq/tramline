FactoryBot.define do
  factory :sign_off_group_membership do
    sign_off_group
    user { nil }
  end
end
