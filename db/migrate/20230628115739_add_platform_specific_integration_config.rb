class AddPlatformSpecificIntegrationConfig < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :deployments, bulk: true do |t|
        add_column :app_configs, :firebase_ios_config, :jsonb, null: true
        add_column :app_configs, :firebase_android_config, :jsonb, null: true
      end
    end
  end
end
