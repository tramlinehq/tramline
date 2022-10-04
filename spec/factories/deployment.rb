FactoryBot.define do
  factory :deployment do
    association :step, factory: :releases_step
  end
end
