class AddCoreEnabledFlag < ActiveRecord::Migration[7.2]
  def change
    add_column :notification_settings, :core_enabled, :boolean, default: false, null: false
  end
end
