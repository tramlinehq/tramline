FactoryBot.define do
  factory :deployment do
    sequence(:build_artifact_channel) { |n| {id: n} }

    trait :with_step do
      before(:create) do |deployment, _|
        build(:releases_step)
          .tap { |step| step.deployments << deployment }
          .save
      end
    end
  end
end
