FactoryBot.define do
  factory :releases_step_run, class: "Releases::Step::Run" do
    build_version { "1.1.1-qa-dev" }
    association :train, factory: "releases_train"
    association :commit, factory: :releases_commit
    association :step, factory: :releases_step
    association :train_run, factory: :releases_train_run
    scheduled_at { Time.current }
    status { "on_track" }
  end
end
