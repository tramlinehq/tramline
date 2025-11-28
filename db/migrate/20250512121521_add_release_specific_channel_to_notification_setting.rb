class AddReleaseSpecificChannelToNotificationSetting < ActiveRecord::Migration[7.2]
  def change
    add_column :notification_settings, :release_specific_channel, :jsonb
    add_column :notification_settings, :release_specific_enabled, :boolean, default: false
  end
end
