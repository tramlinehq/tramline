FactoryBot.define do
  factory :train do
    association :app, factory: [:app, :android]
    version_seeded_with { "1.1.1" }
    name { "train" }
    description { "train description" }
    branching_strategy { "release_backmerge" }
    working_branch { "dev" }
    release_backmerge_branch { "main" }
    status { "draft" }
    build_queue_enabled { false }

    trait :draft do
      status { "draft" }
    end

    trait :active do
      status { "active" }
    end

    trait :inactive do
      status { "inactive" }
    end

    trait :with_almost_trunk do
      branching_strategy { "almost_trunk" }
      release_backmerge_branch { nil }
      release_branch { nil }
    end

    trait :with_release_backmerge do
      branching_strategy { "release_backmerge" }
      release_backmerge_branch { "main" }
      release_branch { nil }
    end

    trait :with_parallel_working do
      branching_strategy { "parallel_working" }
      release_branch { "main" }
      release_backmerge_branch { nil }
    end

    trait :with_schedule do
      branching_strategy { "almost_trunk" }
      kickoff_at { 2.hours.from_now }
      repeat_duration { 1.day }
    end

    trait :with_build_queue do
      build_queue_enabled { true }
      build_queue_size { 2 }
      build_queue_wait_time { 1.hour }
    end
  end
end
