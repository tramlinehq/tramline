FactoryBot.define do
  factory :test_flight_submission do
    parent_release { association :internal_release }
    build { association :build, release_platform_run: parent_release.release_platform_run }
    release_platform_run { parent_release.release_platform_run }
    sequence_number { 1 }

    status { "created" }
    submission_config {
      {
        submission_config: {
          id: "123",
          name: "External Testers",
          is_internal: false
        },
        auto_promote: true
      }
    }

    trait :created do
      status { "created" }
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

    trait :finished do
      status { "finished" }
      approved_at { Time.current }
    end

    trait :failed do
      status { "failed" }
      failure_reason { "unknown_failure" }
    end
  end
end
