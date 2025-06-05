FactoryBot.define do
  factory :submission_config, class: "Config::Submission" do
    association :release_step_config
    sequence(:number) { |n| n }
    submission_type { "PlayStoreSubmission" }
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