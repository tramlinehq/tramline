class AddPlatformSpecificBitriseConfig < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :app_configs, bulk: true do |t|
        t.column :bitrise_ios_config, :jsonb, null: true
        t.column :bitrise_android_config, :jsonb, null: true
      end
    end
  end
end
