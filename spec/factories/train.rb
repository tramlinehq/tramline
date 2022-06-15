FactoryBot.define do
  factory :train, class: Releases::Train do
    name { 'MyString' }
    status { 'active' }
    version_seeded_with { 1 }
  end
end
