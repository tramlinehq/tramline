FactoryBot.define do
  factory :deployment do
    association :step, factory: :releases_step
    sequence(:build_artifact_channel) { |n| {id: n} }
  end
end
