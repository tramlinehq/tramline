FactoryBot.define do
  factory :release_health_event do
    association :deployment_run
    association :release_health_rule
    association :release_health_metric

    health_status { "healthy" }
    event_timestamp { Time.current }

    trait :healthy do
      health_status { "healthy" }
    end

    trait :unhealthy do
      health_status { "unhealthy" }
    end
  end
end
