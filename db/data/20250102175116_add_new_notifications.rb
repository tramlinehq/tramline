# frozen_string_literal: true

class AddNewNotifications < ActiveRecord::Migration[7.2]
  def up
    ActiveRecord::Base.transaction do
      Train.all.where.not(notification_channel: nil).each do |train|
        next if train.notification_settings.empty?

        finalize_failed_setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:release_finalize_failed])
        beta_release_failed_setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:beta_release_failed])
        next if finalize_failed_setting.present? && beta_release_failed_setting.present?

        submission_failed_setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:submission_failed])

        if finalize_failed_setting.blank?
          train.notification_settings.create!(
            kind: NotificationSetting.kinds[:release_finalize_failed],
            notification_channels: submission_failed_setting.notification_channels,
            active: submission_failed_setting.active
          )
        end

        if beta_release_failed_setting.blank?
          train.notification_settings.create!(
            kind: NotificationSetting.kinds[:beta_release_failed],
            notification_channels: submission_failed_setting.notification_channels,
            active: submission_failed_setting.active
          )
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
