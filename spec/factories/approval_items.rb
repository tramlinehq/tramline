FactoryBot.define do
  factory :approval_item do
    release
    author { release.organization.owner }
    content { Faker::Lorem.paragraph }
  end
end
