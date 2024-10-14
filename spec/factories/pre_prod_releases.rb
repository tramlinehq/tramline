FactoryBot.define do
  factory :pre_prod_release do
    release_platform_run
    commit
    type { "InternalRelease" }
    status { "created" }
    config {
      {
        auto_promote: true,
        submissions: [
          {
            number: 1,
            submission_type: "PlayStoreSubmission",
            submission_config: {id: :internal, name: "internal testing"},
            rollout_config: {enabled: true, stages: [100]},
            auto_promote: true,
            integrable_id: release_platform_run.app.id,
            integrable_type: "App"
          },
          {
            number: 2,
            submission_type: "PlayStoreSubmission",
            submission_config: {id: :alpha, name: "closed testing"},
            rollout_config: {enabled: true, stages: [10, 100]},
            auto_promote: true,
            integrable_id: release_platform_run.app.id,
            integrable_type: "App"
          }
        ]
      }
    }

    trait :single_submission do
      config {
        {
          auto_promote: true,
          submissions: [
            {
              number: 1,
              submission_type: "PlayStoreSubmission",
              submission_config: {id: :internal, name: "internal testing"},
              rollout_config: {enabled: true, stages: [100]},
              auto_promote: true,
              integrable_id: release_platform_run.app.id,
              integrable_type: "App"
            }
          ]
        }
      }
    end
  end
end
