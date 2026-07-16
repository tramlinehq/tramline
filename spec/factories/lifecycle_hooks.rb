# frozen_string_literal: true

FactoryBot.define do
  factory :lifecycle_hook do
    train
    name { "Test hook" }
    event { "ios_submission_started" }
    http_method { "POST" }
    url { "https://example.com/hook" }
    headers { {"Content-Type" => "application/json"} }
    body_template { '{"build_number": %{build_number}}' }
    static_variables { {} }
    auth_type { "none" }
    notify_on_failure { false }
    active { true }

    trait :basic_auth do
      auth_type { "basic" }
      auth_username { "user" }
      auth_secret { "secret" }
    end

    trait :bearer_auth do
      auth_type { "bearer" }
      auth_secret { "token" }
    end

    trait :with_failure_notify do
      notify_on_failure { true }
      failure_message_template { "Hook %{hook_name} failed for build %{build_number}" }
      failure_notification_channel { {"id" => "C12345", "name" => "alerts"} }
    end

    trait :inactive do
      active { false }
    end
  end
end
