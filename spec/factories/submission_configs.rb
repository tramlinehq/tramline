FactoryBot.define do
  factory :submission_config, class: "Config::Submission" do
    release_step_config
    submission_type { "PlayStoreSubmission" }
    auto_start_rollout_after_submission { false }
    rollout_enabled { false }
    rollout_stages { [] }
    auto_promote { false }

    trait :with_external do
      after(:create) do |submission|
        create(:submission_external_config, submission_config: submission)
      end
    end

    trait :with_rollout do
      rollout_enabled { true }
      rollout_stages { [0.2, 0.5, 1.0] }
    end
  end
end
