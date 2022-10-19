FactoryBot.define do
  factory :releases_step, class: "Releases::Step" do
    association :train, factory: :releases_train
    name { Faker::Lorem.word }
    description { Faker::Lorem.sentence }
    sequence(:ci_cd_channel) { |n| Faker::Lorem.word + n.to_s }
    build_artifact_channel { Faker::Lorem.word }
    release_suffix { "qa-staging" }
    build_artifact_integration { "SlackIntegration" }
  end
end
