FactoryBot.define do
  factory :workflow_run do
    association :commit
    association :triggering_release, factory: :internal_release
    release_platform_run { triggering_release.release_platform_run }
    workflow_config { {id: "123"} }
    status { "created" }

    trait :triggered do
      status { "triggered" }
    end

    trait :started do
      status { "started" }
    end

    trait :failed do
      status { "failed" }
    end

    trait :finished do
      status { "finished" }
    end

    trait :unavailable do
      status { "unavailable" }
    end

    trait :halted do
      status { "halted" }
    end

    trait :cancelling do
      status { "cancelling" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end
