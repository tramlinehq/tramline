FactoryBot.define do
  factory :approval_item do
    release
    author { release.organization.owner }
    content { Faker::Lorem.characters(number: ApprovalItem::MAX_CONTENT_LENGTH) }

    trait :approved do
      status { "approved" }
    end
  end
end
