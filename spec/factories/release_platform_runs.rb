FactoryBot.define do
  factory :release_platform_run do
    association :release_platform
    release { association :release }
    code_name { Faker::FunnyName.name }
    scheduled_at { Time.current }
    status { "on_track" }
    release_version { "1.2.3" }

    trait :created do
      status { "created" }
    end

    trait :on_track do
      status { "on_track" }
    end

    trait :post_release_started do
      status { "post_release_started" }
    end
  end
end
