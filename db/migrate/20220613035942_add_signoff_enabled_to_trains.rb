class AddSignoffEnabledToTrains < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :signoff_enabled, :boolean, default: false
  end
end
