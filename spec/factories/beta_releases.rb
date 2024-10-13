FactoryBot.define do
  factory :beta_release do
    release_platform_run
    commit
    type { "BetaRelease" }
    status { "created" }
    config {
      {
        auto_promote: false,
        submissions: [
          {
            number: 1,
            submission_type: "PlayStoreSubmission",
            submission_config: {id: :beta, name: "open testing"},
            rollout_config: {enabled: true, stages: [10, 100]},
            auto_promote: true,
            integrable_id: release_platform_run.app.id,
            integrable_type: "App"
          }
        ]
      }
    }
  end
end
