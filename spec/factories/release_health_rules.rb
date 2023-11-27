FactoryBot.define do
  factory :release_health_rule do
    association :train

    comparator { "gte" }
    threshold_value { 90.0 }

    trait :session_stability do
      metric { "session_stability" }
    end

    trait :user_stability do
      metric { "user_stability" }
    end

    trait :errors do
      metric { "errors" }
      threshold_value { 90 }
      comparator { "lt" }
    end

    trait :new_errors do
      metric { "new_errors" }
      threshold_value { 10 }
      comparator { "lt" }
    end
  end
end
