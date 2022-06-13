FactoryBot.define do
  factory :releases_train, class: 'Releases::Train' do
    version_seeded_with { '1.1.1' }
    app
    name { 'train' }
    description { 'train description' }
    version_suffix { '-train' }
  end
end
