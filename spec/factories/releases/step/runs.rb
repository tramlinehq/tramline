FactoryBot.define do
  factory :releases_step_run, class: "Releases::Step::Run" do
    sequence(:build_version) { |n| "1.1.#{n}-qa-dev" }
    association :commit, factory: :releases_commit
    association :step, factory: [:releases_step, :with_deployment]
    association :train_run, factory: :releases_train_run
    scheduled_at { Time.current }
    status { "on_track" }
    sequence(:build_number) { |n| 123 + n }
  end
end
