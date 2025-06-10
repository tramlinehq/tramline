# frozen_string_literal: true

class AddRcFinishedNotification < ActiveRecord::Migration[7.2]
  def up
    Train.active.find_each do |train|
      next unless train.send_notifications?

      train.notification_settings.create!(
        kind: NotificationSetting.kinds[:rc_finished],
        active: false,
        core_enabled: false,
        release_specific_enabled: false,
        notification_channels: [train.notification_channel]
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
