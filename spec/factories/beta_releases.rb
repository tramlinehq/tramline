FactoryBot.define do
  factory :beta_release do
    association :release_platform_run
    association :commit
    type { "BetaRelease" }
    status { "created" }
    config {
      {auto_promote: false,
       submissions: [
         {number: 1,
          submission_type: "PlayStoreSubmission",
          submission_config: {id: :beta, name: "open testing"},
          rollout_config: {enabled: true, stages: [10, 100]},
          auto_promote: true}
       ]}
    }
  end
end
