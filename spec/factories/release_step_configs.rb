FactoryBot.define do
  factory :release_step_config, class: "Config::ReleaseStep" do
    association :release_platform_config
    auto_promote { false }
    kind { "beta" }  # Default to beta since it's required

    trait :internal do
      kind { "internal" }
    end

    trait :beta do
      kind { "beta" }
    end

    trait :production do
      kind { "production" }
    end

    trait :with_submissions do
      after(:create) do |release_step|
        create(:submission_config, release_step_config: release_step)
      end
    end
  end
end 