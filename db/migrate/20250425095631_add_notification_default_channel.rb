class AddNotificationDefaultChannel < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :notifications_default_channel, :boolean, default: true
  end
end
