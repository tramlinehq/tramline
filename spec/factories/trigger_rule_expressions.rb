FactoryBot.define do
  factory :trigger_rule_expression do
    association :release_health_rule

    comparator { "lt" }
    threshold_value { 90.0 }

    trait :session_stability do
      metric { "session_stability" }
    end

    trait :user_stability do
      metric { "user_stability" }
    end

    trait :errors do
      metric { "errors_count" }
      threshold_value { 90 }
      comparator { "gte" }
    end

    trait :new_errors do
      metric { "new_errors_count" }
      threshold_value { 10 }
      comparator { "gte" }
    end
  end
end
