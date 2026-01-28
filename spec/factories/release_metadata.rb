FactoryBot.define do
  factory :release_metadata do
    release
    release_platform_run
    locale { ReleaseMetadata::DEFAULT_LOCALE }
    description { Faker::Lorem.paragraph }
    keywords { Faker::Lorem.words(number: 3) }
    promo_text { Faker::Lorem.paragraph }
    release_notes { Faker::Lorem.paragraph }
    draft_release_notes { nil }
    draft_promo_text { nil }

    trait :with_draft do
      draft_release_notes { Faker::Lorem.paragraph }
      draft_promo_text { Faker::Lorem.paragraph }
    end
  end
end
