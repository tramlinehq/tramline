FactoryBot.define do
  factory :sign_off do
    sign_off_group
    association :user
    association :step, factory: :releases_step
    association :commit, factory: :releases_commit
  end
end
