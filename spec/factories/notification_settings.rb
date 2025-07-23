# frozen_string_literal: true

FactoryBot.define do
  factory :notification_setting do
    active { true }
    core_enabled { true }
    release_specific_enabled { false }
    kind { NotificationSetting::RELEASE_SPECIFIC_CHANNEL_NOT_ALLOWED_KINDS.sample }
    notification_channels {
      Array.new(Random.rand(1..3)) {
        {
          id: Faker::Alphanumeric.alphanumeric(number: 10),
          name: Faker::Lorem.word, is_private: false
        }
      }
    }
    release_specific_channel { nil }
    user_groups { nil }
    user_content { nil }

    trait :inactive do
      active { false }
      core_enabled { false }
      release_specific_enabled { false }
    end

    trait :release_specific do
      release_specific_enabled { true }
      kind { NotificationSetting::RELEASE_SPECIFIC_CHANNEL_ALLOWED_KINDS.sample }
      release_specific_channel { {id: Faker::Alphanumeric.alphanumeric(number: 10), name: Faker::Lorem.word, is_private: false} }

      after(:build) do |notification_setting|
        notification_setting.train.update(notifications_release_specific_channel_enabled: true)
      end
    end

    trait :only_release_specific do
      release_specific
      core_enabled { false }
    end

    trait :threaded_changelog do
      kind { NotificationSetting::THREADED_CHANGELOG_NOTIFICATION_KINDS.sample }
    end

    trait :with_user_content do
      user_content { "Custom notification content from the team" }
    end

    train factory: %i[train with_no_platforms without_notification_settings]
  end
end
