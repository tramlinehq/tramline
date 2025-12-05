FactoryBot.define do
  factory :accounts_custom_storage, class: "Accounts::CustomStorage" do
    organization { association :organization }
    bucket { "test-bucket-#{SecureRandom.hex(4)}" }
    bucket_region { "us-central1" }
    service { "google" }
  end
end
