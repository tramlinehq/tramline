FactoryBot.define do
  factory :releases_step, class: "Releases::Step" do
    association :train, factory: :releases_train
    name { Faker::Lorem.word }
    description { Faker::Lorem.sentence }
    sequence(:ci_cd_channel) { |n| Faker::Lorem.word + n.to_s }
    release_suffix { "qa-staging" }

    trait :with_deployment do
      after(:build) do |step, _|
        build(:deployment, step: step)
      end
    end
  end
end
