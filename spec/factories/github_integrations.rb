FactoryBot.define do
  factory :github_integration do
    installation_id { 1 }
    repository_config { {id: 123, full_name: "tramline/repo", namespace: "tramline"} }
  end
end
