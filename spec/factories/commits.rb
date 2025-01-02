FactoryBot.define do
  factory :commit do
    commit_hash { SecureRandom.uuid.split("-").join }
    release { association :release }
    message { Faker::Lorem.sentence }
    timestamp { Time.current }
    author_name { Faker::Name.name }
    author_email { Faker::Internet.email }
    author_login { Faker::Internet.user_name }
    url { Faker::Internet.url }
  end
end
