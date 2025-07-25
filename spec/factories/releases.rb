FactoryBot.define do
  factory :release do
    train
    scheduled_at { Time.current }
    status { "on_track" }
    branch_name { "branch" }
    original_release_version { VersioningStrategies::Semverish.new(train.version_seeded_with).bump!(:minor) }
    release_type { "release" }
    release_pilot_id { train.app.organization.owner.id }

    trait :hotfix do
      release_type { "hotfix" }
    end

    trait :created do
      status { "created" }
    end

    trait :on_track do
      status { "on_track" }
    end

    trait :post_release_started do
      status { "post_release_started" }
    end

    trait :post_release_failed do
      status { "post_release_failed" }
    end

    trait :finished do
      status { "finished" }
      completed_at { Time.current }
    end

    trait :partially_finished do
      status { "partially_finished" }
    end

    trait :with_no_platform_runs do
      after(:build) do |release|
        def release.create_platform_runs! = true
      end
    end
  end
end
