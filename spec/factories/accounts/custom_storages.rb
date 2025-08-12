FactoryBot.define do
  factory :accounts_custom_storage, class: 'Accounts::CustomStorage' do
    association :organization, factory: :organization
    bucket { "test-bucket" }
    project_id { "test-project" }
    credentials { { "private_key": "test_private_key" } }
  end
end
