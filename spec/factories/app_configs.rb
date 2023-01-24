FactoryBot.define do
  factory :app_config do
    code_repository { {id: 123, full_name: "tramline/repo", namespace: "tramline"} }
    notification_channel { {id: 123, name: "build_notifications"} }
    association :app, factory: :app
  end
end
