FactoryBot.define do
  factory :release_health_rule do
    association :release_platform

    name { Faker::Lorem.word }

    trait :session_stability do
      after(:create) do |release_health_rule, _|
        create(:trigger_rule_expression, :session_stability, release_health_rule:)
      end
    end

    trait :user_stability do
      after(:create) do |release_health_rule, _|
        create(:trigger_rule_expression, :user_stability, release_health_rule:)
      end
    end

    trait :errors do
      after(:create) do |release_health_rule, _|
        create(:trigger_rule_expression, :errors, release_health_rule:)
      end
    end

    trait :new_errors do
      after(:create) do |release_health_rule, _|
        create(:trigger_rule_expression, :new_errors, release_health_rule:)
      end
    end
  end
end
