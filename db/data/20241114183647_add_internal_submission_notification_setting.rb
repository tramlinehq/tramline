# frozen_string_literal: true

class AddInternalSubmissionNotificationSetting < ActiveRecord::Migration[7.2]
  def up
    return
    ActiveRecord::Base.transaction do
      Train.all.where.not(notification_channel: nil).each do |train|
        next if train.notification_settings.empty?

        setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:internal_submission_finished])
        next if setting.present?
        internal_release_finished_setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:internal_release_finished])

        train.notification_settings.create!(
          kind: NotificationSetting.kinds[:internal_submission_finished],
          notification_channels: internal_release_finished_setting.notification_channels,
          active: internal_release_finished_setting.active
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
