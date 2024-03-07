class AddPlatformSpecificBugsnagConfig < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :app_configs, bulk: true do |t|
        t.column :bugsnag_ios_config, :jsonb, null: true
        t.column :bugsnag_android_config, :jsonb, null: true
      end
    end
  end
end
