FactoryBot.define do
  factory :pull_request do
    release
    number { 1 }
    source_id { "id" }
    url { Faker::Internet.url }
    title { Faker::Lorem.word }
    body { Faker::Lorem.paragraph }
    state { "open" }
    source { "github" }
    phase { "ongoing" }
    head_ref { Faker::Lorem.word }
    base_ref { Faker::Lorem.word }
    opened_at { Time.current }
  end
end
