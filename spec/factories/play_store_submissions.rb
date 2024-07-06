FactoryBot.define do
  factory :play_store_submission do
    parent_release { association :pre_prod_release }
    build { association :build, release_platform_run: parent_release.release_platform_run }
    release_platform_run { parent_release.release_platform_run }
    sequence_number { 1 }

    status { "created" }
    submission_config {
      {
        submission_config: {
          id: :production,
          name: "production"
        },
        rollout_config: {
          enabled: true,
          stages: [1, 5, 10, 20, 50, 100]
        }
      }
    }

    trait :pre_prod_release do
      parent_release { association :pre_prod_release }
    end

    trait :prod_release do
      parent_release { association :production_release }
    end

    trait :preparing do
      status { "preparing" }
    end

    trait :prepared do
      status { "prepared" }
      prepared_at { Time.current }
    end

    trait :review_failed do
      status { "review_failed" }
      rejected_at { Time.current }
    end

    trait :failed do
      status { "failed" }
      failure_reason { "unknown_failure" }
    end
  end
end
