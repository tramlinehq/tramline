FactoryBot.define do
  factory :outgoing_webhook_event do
    release factory: [:release]
    event_timestamp { Time.current }
    event_payload { {foo: :bar} }
    event_type { "rc.finished" }
    status { :pending }

    trait :success do
      status { :success }
      response_data { '{"id": "msg_123", "status": "delivered"}' }
    end

    trait :failed do
      status { :failed }
      error_message { "Connection timeout" }
    end
  end
end
