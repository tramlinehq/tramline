class AddFirebaseCrashlyticsConfigToAppConfig < ActiveRecord::Migration[7.2]
  def change
    add_column :app_configs, :firebase_crashlytics_ios_config, :jsonb
    add_column :app_configs, :firebase_crashlytics_android_config, :jsonb
  end
end
