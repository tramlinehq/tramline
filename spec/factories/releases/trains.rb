FactoryBot.define do
  factory :releases_train, class: "Releases::Train" do
    app { association :app, :android }
    version_seeded_with { "1.1.1" }
    name { "train" }
    description { "train description" }
    branching_strategy { "release_backmerge" }
    working_branch { "dev" }
    release_backmerge_branch { "main" }

    trait :active do
      status { "active" }
    end

    trait :inactive do
      status { "inactive" }
    end

    trait :with_almost_trunk do
      branching_strategy { "almost_trunk" }
      release_backmerge_branch { nil }
      release_branch { nil }
    end

    trait :with_release_backmerge do
      branching_strategy { "release_backmerge" }
      release_backmerge_branch { "main" }
      release_branch { nil }
    end

    trait :with_parallel_working do
      branching_strategy { "parallel_working" }
      release_branch { "main" }
      release_backmerge_branch { nil }
    end
  end
end
