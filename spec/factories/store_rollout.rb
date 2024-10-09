FactoryBot.define do
  factory :store_rollout do
    config { [1, 100] }
    current_stage { nil }
    is_staged_rollout { true }
    release_platform_run
    store_submission factory: :play_store_submission

    type { "PlayStoreRollout" }
    initialize_with { type.constantize.new }

    trait :play_store do
      store_submission factory: :play_store_submission
      type { "PlayStoreRollout" }
    end

    trait :app_store do
      store_submission factory: :app_store_submission
      type { "AppStoreRollout" }
    end

    trait :created do
      status { "created" }
    end

    trait :started do
      status { "started" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :paused do
      status { "paused" }
    end

    trait :halted do
      status { "halted" }
    end

    trait :fully_released do
      status { "fully_released" }
    end
  end
end
