class AddNotificationReleaseSpecificChannel < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :notifications_release_specific_channel_enabled, :boolean, default: false
  end
end
