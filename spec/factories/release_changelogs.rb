FactoryBot.define do
  factory :release_changelog do
    release
    from_ref { "v1.10.0" }

    after(:create) do |changelog|
      # Create associated commits through the release
      rand(1..10).times do
        create(:commit,
          release: changelog.release,
          url: Faker::Internet.url,
          message: Faker::Lorem.sentence,
          parents: [],
          timestamp: Time.current,
          author_name: Faker::Name.name,
          commit_hash: SecureRandom.hex,
          author_email: Faker::Internet.email,
          author_login: Faker::Internet.user_name)
      end
    end
  end
end
