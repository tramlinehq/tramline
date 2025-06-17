# frozen_string_literal: true

FactoryBot.define do
  factory :notification_setting do
    active { true }
    core_enabled { true }
    release_specific_enabled { false }
    kind { NotificationSetting::RELEASE_SPECIFIC_CHANNEL_NOT_ALLOWED_KINDS.sample }
    notification_channels { [{id: Faker::Alphanumeric.alphanumeric(number: 10), name: Faker::Lorem.word, is_private: false}] }
    release_specific_channel { nil }
    user_groups { nil }

    trait :release_specific do
      release_specific_enabled { true }
      kind { NotificationSetting::RELEASE_SPECIFIC_CHANNEL_ALLOWED_KINDS.sample }
      release_specific_channel { {id: Faker::Alphanumeric.alphanumeric(number: 10), name: Faker::Lorem.word, is_private: false} }
    end

    trait :threaded_changelog do
      kind { NotificationSetting::THREADED_CHANGELOG_NOTIFICATION_KINDS.sample }
    end

    train factory: %i[train with_no_platforms without_notification_settings]
  end
end
