FactoryBot.define do
  factory :outgoing_webhook do
    train factory: [:train, :with_no_platforms]
    url { "https://example.com/webhook" }
    description { "Test webhook for release events" }
    active { true }
    event_types { ["release.started"] }

    trait :inactive do
      active { false }
    end

    trait :multiple_events do
      event_types { ["release.started", "release.ended", "rc.finished"] }
    end

    trait :rc_events do
      event_types { ["rc.finished"] }
    end
  end
end
