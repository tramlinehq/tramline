FactoryBot.define do
  factory :external_app do
    default_locale { "en-US" }
    fetched_at { Time.current }

    trait :ios do
      association :app, :ios
      platform { "ios" }
      channel_data { IOS_CHANNEL_DATA }
    end

    trait :android do
      association :app, :android
      platform { "android" }
      channel_data { ANDROID_CHANNEL_DATA }
    end
  end
end

IOS_CHANNEL_DATA = [
  {
    "name" => "alpha",
    "releases" => [
      {
        "localizations" => [
          {
            "language" => "en-US",
            "description" => "Description",
            "whats_new" => "What's New",
            "keywords" => "keyword1, keyword2",
            "promo_text" => "Promo Text"
          }
        ],
        "version_string" => "1.0.0",
        "status" => "completed",
        "build_number" => "1",
        "id" => "1",
        "release_date" => "2021-01-01T00:00:00Z"
      }
    ]
  }
]

ANDROID_CHANNEL_DATA = [
  {
    "name" => "production",
    "releases" => [
      {
        "status" => "inProgress",
        "build_number" => "3",
        "localizations" => [
          {
            "text" => "This latest version includes bugfixes for the android platform.",
            "language" => "en-US"
          }
        ],
        "user_fraction" => 0.01,
        "version_string" => "1.10.0"
      },
      {
        "status" => "completed",
        "build_number" => "2",
        "localizations" => [
          {
            "text" => "The latest version contains bug fixes and performance improvements.",
            "language" => "en-US"
          }
        ],
        "user_fraction" => nil,
        "version_string" => "1.20.0"
      }
    ]
  },
  {
    "name" => "beta",
    "releases" => [
      {
        "status" => "completed",
        "build_number" => "1",
        "localizations" => [
          {
            "text" => "• Update README.md\n• new RC build\n• new and improved RC",
            "language" => "en-GB"
          }
        ],
        "user_fraction" => nil,
        "version_string" => "1.10.0"
      }
    ]
  }
]
