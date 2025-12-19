FactoryBot.define do
  factory :workflow_config, class: "Config::Workflow" do
    association :release_platform_config
    sequence(:name) { |n| "Workflow #{n}" }
    sequence(:identifier) { |n| "workflow_#{n}" }
    kind { "release_candidate" }
    artifact_name_pattern { nil }

    trait :internal do
      kind { "internal" }
    end

    trait :release_candidate do
      kind { "release_candidate" }
    end
  end
end
