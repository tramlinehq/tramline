FactoryBot.define do
  factory :external_release do
    association :deployment_run
    build_number { Faker::Number.number(digits: 4) }
    name { Faker::Name.name }
    added_at { Time.current }
  end
end
