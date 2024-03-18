# frozen_string_literal: true

class AddStagedRolloutCompletedNotificationSetting < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      Train.all.where.not(notification_channel: nil).each do |train|
        next if train.notification_settings.empty?

        rollout_completed_setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:staged_rollout_completed])
        next if rollout_completed_setting.present?

        staged_rollout_updated_setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:staged_rollout_updated])
        train.notification_settings.create!(
          kind: NotificationSetting.kinds[:staged_rollout_completed],
          active: staged_rollout_updated_setting.active,
          notification_channels: staged_rollout_updated_setting.notification_channels
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
