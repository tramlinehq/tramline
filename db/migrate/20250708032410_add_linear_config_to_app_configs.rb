class AddLinearConfigToAppConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :app_configs, :linear_config, :jsonb, default: {}, null: false
  end
end
