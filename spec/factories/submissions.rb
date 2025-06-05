FactoryBot.define do
  factory :submission do
    sequence(:number) { |n| n }
    association :release
    integrable_type { "SubmissionType::Android" }
    sequence(:integrable_id) { |n| "variant_#{n}" }
    submission_type { "internal" }

    trait :with_external_submission do
      after(:create) do |submission|
        create(:submission_external, submission: submission)
      end
    end

    trait :with_rollout do
      rollout_enabled { true }
      rollout_stages { [0.2, 0.5, 1.0] }
      finish_rollout_in_next_release { false }
    end
  end
end 