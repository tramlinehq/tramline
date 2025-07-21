FactoryBot.define do
  factory :outgoing_webhook_event do
    train factory: [:train, :with_no_platforms]
    outgoing_webhook factory: :outgoing_webhook
    event_timestamp { Time.current }
    status { :pending }

    trait :successful do
      status { :success }
      response_data { '{"id": "msg_123", "status": "delivered"}' }
    end

    trait :failed do
      status { :failed }
      error_message { "Connection timeout" }
    end
  end
end
