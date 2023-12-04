FactoryBot.define do
  factory :filter_rule_expression do
    association :release_health_rule

    comparator { "gte" }
    threshold_value { 50.0 }
    metric { "adoption_rate" }
  end
end
