FactoryBot.define do
  factory :releases_commit, class: "Releases::Commit" do
    commit_hash { SecureRandom.uuid.split("-").join }
    association :train, factory: "releases_train"
    association :train_run, factory: "releases_train_run"
    message { "feat: introduce commit listener" }
    timestamp { "2022-06-21 20:20:21" }
    author_name { "Jon Doe" }
    author_email { "jon@doe.com" }
    url { "https://sample.com" }
  end
end
