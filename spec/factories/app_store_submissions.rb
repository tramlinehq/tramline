FactoryBot.define do
  factory :app_store_submission do
    parent_release { association :production_release }
    build { association :build, release_platform_run: parent_release.release_platform_run }
    release_platform_run { parent_release.release_platform_run }
    sequence_number { 1 }

    status { "created" }
    config {
      {
        submission_config: {id: :production, name: "production"},
        rollout_config: {enabled: true, stages: [1, 5, 10, 50, 100]},
        integrable_id: parent_release.release_platform_run.app.id,
        integrable_type: "App"
      }
    }

    trait :created do
      status { "created" }
    end

    trait :preparing do
      status { "preparing" }
    end

    trait :prepared do
      status { "prepared" }
      prepared_at { Time.current }
    end

    trait :submitting_for_review do
      status { "submitting_for_review" }
    end

    trait :submitted_for_review do
      status { "submitted_for_review" }
      submitted_at { Time.current }
    end

    trait :review_failed do
      status { "review_failed" }
      rejected_at { Time.current }
    end

    trait :approved do
      status { "approved" }
      approved_at { Time.current }
    end

    trait :failed do
      status { "failed" }
      failure_reason { "unknown_failure" }
    end
  end
end
