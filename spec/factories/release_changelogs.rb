FactoryBot.define do
  factory :release_changelog do
    release
    commits {
      Array.new(rand(1..10)) do
        {url: Faker::Internet.url,
         message: Faker::Lorem.sentence,
         parents: [],
         timestamp: Time.current,
         author_url: Faker::Internet.url,
         author_name: Faker::Name.name,
         commit_hash: SecureRandom.hex,
         author_email: Faker::Internet.email,
         author_login: Faker::Internet.user_name}
      end
    }
    from_ref { "v1.10.0" }
  end
end
