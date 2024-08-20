FactoryBot.define do
  factory :production_release do
    release_platform_run { association :release_platform_run }
    build { association :build }
    status { "inflight" }

    trait :active do
      status { "active" }
    end

    trait :inflight do
      status { "inflight" }
    end

    trait :finished do
      status { "finished" }
    end

    trait :stale do
      status { "stale" }
    end
  end
end
