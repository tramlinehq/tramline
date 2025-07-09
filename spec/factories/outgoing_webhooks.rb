FactoryBot.define do
  factory :outgoing_webhook do
    train factory: [:train, :with_no_platforms]
    url { "https://example.com/webhook" }
    description { "Test webhook for release events" }
    active { true }
    event_types { ["release_started"] }

    trait :inactive do
      active { false }
    end

    trait :multiple_events do
      event_types { ["release_started", "build_available", "production_release_complete"] }
    end

    trait :build_events do
      event_types { ["build_available", "workflow_run_finished"] }
    end
  end
end
