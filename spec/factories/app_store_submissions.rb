FactoryBot.define do
  factory :app_store_submission do
    release_platform_run { association :release_platform_run }
    pre_prod_release { association :pre_prod_release }
    production_release { nil }
    status { "created" }

    trait :pre_prod_release do
      pre_prod_release { association :pre_prod_release }
      production_release { nil }
    end

    trait :prod_release do
      pre_prod_release { nil }
      production_release { association :production_release }
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
