FactoryBot.define do
  factory :google_firebase_submission do
    parent_release { association :internal_release }
    build { association :build, release_platform_run: parent_release.release_platform_run }
    release_platform_run { parent_release.release_platform_run }
    sequence_number { 1 }

    status { "created" }
    config {
      {
        submission_config: {id: :production, name: "production"},
        integrable_id: parent_release.release_platform_run.app.id,
        integrable_type: "App"
      }
    }

    trait :with_store_release do
      store_release { {"id" => 1} }
    end

    trait :preprocessing do
      status { "preprocessing" }
    end

    trait :preparing do
      status { "preparing" }
      prepared_at { Time.current }
    end

    trait :finished do
      status { "finished" }
    end

    trait :failed do
      status { "failed" }
      failure_reason { "unknown_failure" }
    end
  end
end
