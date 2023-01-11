FactoryBot.define do
  factory :integration do
    association :app, factory: :app
    association :providable, factory: :github_integration
    category { "version_control" }
  end
end
