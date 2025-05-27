# frozen_string_literal: true

class UpdateNotificationSettingsToAddReleaseSpecificChannels < ActiveRecord::Migration[7.2]
  def up
    return
    # find all trains with release-specific channels enabled
    Train.where(notifications_release_specific_channel_enabled: true).find_each do |train|
      notification_settings = train.notification_settings.release_specific_channel_allowed

      # update all the notification settings (release-specific allowed) to have release-specific enabled
      notification_settings.find_each do |notification_setting|
        notification_setting.update!(
          release_specific_enabled: true,
          # also update the new 'release_specific_channel' to be
          # the last release-specific chan that used to be stored in 'notification_channels'
          release_specific_channel: notification_setting.notification_channels.first,
          notification_channels: [train.notification_channel]
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
