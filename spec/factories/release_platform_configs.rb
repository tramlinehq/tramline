FactoryBot.define do
  factory :release_platform_config, class: "Config::ReleasePlatform" do
    association :release_platform

    after(:build) do |config|
      # Required associations for a valid config
      config.release_candidate_workflow ||= build(:workflow_config, :release_candidate, release_platform_config: config)
      config.beta_release ||= build(:release_step_config, :beta, release_platform_config: config)
    end

    trait :with_internal_release do
      after(:create) do |config|
        create(:workflow_config, :internal, release_platform_config: config)
        create(:release_step_config, :internal, :with_submissions, release_platform_config: config)
      end
    end

    trait :with_beta_release do
      after(:create) do |config|
        create(:release_step_config, :beta, :with_submissions, release_platform_config: config)
      end
    end

    trait :with_production_release do
      after(:create) do |config|
        create(:release_step_config, :production, :with_submissions, release_platform_config: config)
      end
    end
  end
end 