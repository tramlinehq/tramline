FactoryBot.define do
  factory :scheduled_release do
    train
    release
    is_success { false }
    manually_skipped { false }
    scheduled_at { Time.current }
  end
end
