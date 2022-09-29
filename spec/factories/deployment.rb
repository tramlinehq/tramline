FactoryBot.define do
  factory :deployment do
    association :step, factory: :releases_step
    sequence(:deployment_number) { |n| n }
  end
end
