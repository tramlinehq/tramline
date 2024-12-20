FactoryBot.define do
  factory :app_config do
    code_repository { {id: 123, full_name: "tramline/repo", namespace: "tramline"} }
    app factory: %i[app android without_config]
  end
end