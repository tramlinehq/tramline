FactoryBot.define do
  factory :release_metadata do
    release
    release_platform_run
    locale { ReleaseMetadata::DEFAULT_LOCALE }
    description { Faker::Lorem.paragraph }
    keywords { Faker::Lorem.words(number: 3) }
    promo_text { Faker::Lorem.paragraph }
    release_notes { Faker::Lorem.paragraph }
  end
end
