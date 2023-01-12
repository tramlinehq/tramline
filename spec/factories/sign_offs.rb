FactoryBot.define do
  factory :sign_off do
    sign_off_group
    association :user
    association :step, factory: [:releases_step, :with_deployment]
    commit { association :releases_commit, train: step.train }
  end
end
