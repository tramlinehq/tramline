# frozen_string_literal: true

class AddDeploymentFailedNotificationSettings < ActiveRecord::Migration[7.0]
  def up
    return
    ActiveRecord::Base.transaction do
      Train.all.where.not(notification_channel: nil).each do |train|
        next if train.notification_settings.empty?

        deployment_failed_setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:deployment_failed])
        next if deployment_failed_setting.present?

        step_failed_setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:step_failed])
        train.notification_settings.create!(
          kind: NotificationSetting.kinds[:deployment_failed],
          active: step_failed_setting.active,
          notification_channels: step_failed_setting.notification_channels
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
