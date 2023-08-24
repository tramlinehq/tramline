FactoryBot.define do
  factory :commit do
    commit_hash { SecureRandom.uuid.split("-").join }
    release { association :release }
    build_queue { association :build_queue }
    message { "feat: introduce commit listener" }
    timestamp { Time.current }
    author_name { "Jon Doe" }
    author_email { "jon@doe.com" }
    url { "https://sample.com" }

    trait :without_trigger do
      after(:build) do |commit|
        def commit.trigger_step_runs = true
      end
    end
  end
end
