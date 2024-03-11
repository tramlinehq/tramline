FactoryBot.define do
  factory :step do
    release_platform { association :release_platform }
    association :integration
    name { Faker::Lorem.word }
    description { Faker::Lorem.sentence }
    sequence(:ci_cd_channel) { |n| Faker::Lorem.word + n.to_s }
    release_suffix { "qa-staging" }
    kind { "review" }
    auto_deploy { true }

    trait :release do
      kind { "release" }
    end

    trait :review do
      kind { "review" }
    end

    trait :with_deployment do
      after(:build) do |step, _|
        build(:deployment, step: step)
      end
    end

    before(:create) do |step, _|
      step.integration = step.app.ci_cd_provider.integration
    end
  end
end
