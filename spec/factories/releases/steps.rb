FactoryBot.define do
  factory :releases_step, class: 'Releases::Step' do
    association :train, factory: :releases_train
    name { Faker::Lorem.word }
    description { Faker::Lorem.sentence }
    run_after_duration { Faker::Number.number(digits: 2) }
    ci_cd_channel { Faker::Lorem.word }
    build_artifact_channel { Faker::Lorem.word }
  end
end
