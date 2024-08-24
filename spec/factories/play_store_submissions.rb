FactoryBot.define do
  factory :play_store_submission do
    parent_release { association :pre_prod_release }
    build { association :build, release_platform_run: parent_release.release_platform_run }
    release_platform_run { parent_release.release_platform_run }
    sequence_number { 1 }

    status { "created" }
    config {
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

    trait :with_internal_channel do
      parent_release { association :pre_prod_release }
      config {
        {
          submission_config: {
            id: :internal,
            name: "internal testing"
          }
        }
      }
    end

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

    trait :review_failed do
      status { "review_failed" }
      rejected_at { Time.current }
    end

    trait :failed do
      status { "failed" }
      failure_reason { "unknown_failure" }
    end

    trait :failed_with_action_required do
      status { "failed_with_action_required" }
      failure_reason { "app_review_rejected" }
    end
  end
end

def play_store_review_error
  error_body = {
    "error" =>
      {
        "status" => "INVALID_ARGUMENT",
        "code" => 400,
        "message" => "Changes cannot be sent for review automatically. Please set the query parameter changesNotSentForReview to true. Once committed, the changes in this edit can be sent for review from the Google Play Console UI"
      }
  }

  Installations::Google::PlayDeveloper::Error.new(Google::Apis::ClientError.new("Error", body: error_body.to_json))
end
