FactoryBot.define do
  factory :app_config do
    code_repository { {id: 123, full_name: "tramline/repo", namespace: "tramline"} }
    notification_channel { {id: 123, name: "build_notifications"} }
    # This code is added because in some of our test cases, we need an associated record when creating a train. Without it, the spec fails.
    ci_cd_workflows do
      [
        {id: 1, name: "Test APK"}
      ]
    end
    app factory: %i[app android without_config]
  end
end
