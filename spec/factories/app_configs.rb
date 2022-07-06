FactoryBot.define do
  factory :app_config do
    code_repository { {123 => "tramline/repo"} }
    notification_channel { {123 => "build_notifications"} }
    association :app, factory: :app
  end
end
