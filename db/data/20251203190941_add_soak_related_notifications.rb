# frozen_string_literal: true

class AddSoakRelatedNotifications < ActiveRecord::Migration[7.2]
  def up
    ActiveRecord::Base.transaction do
      Train.all.where.not(notification_channel: nil).each do |train|
        next if train.notification_settings.empty?

        setting_1 = train.notification_settings.find_by(kind: NotificationSetting.kinds[:soak_period_started])
        setting_2 = train.notification_settings.find_by(kind: NotificationSetting.kinds[:soak_period_ended])
        setting_3 = train.notification_settings.find_by(kind: NotificationSetting.kinds[:soak_period_extended])

        if setting_1.blank?
          train.notification_settings.create!(
            kind: NotificationSetting.kinds[:soak_period_started],
            notification_channels: [train.notification_channel],
            release_specific_enabled: false,
            core_enabled: false,
            active: false
          )
        end

        if setting_2.blank?
          train.notification_settings.create!(
            kind: NotificationSetting.kinds[:soak_period_ended],
            notification_channels: [train.notification_channel],
            release_specific_enabled: false,
            core_enabled: false,
            active: false
          )
        end

        if setting_3.blank?
          train.notification_settings.create!(
            kind: NotificationSetting.kinds[:soak_period_extended],
            notification_channels: [train.notification_channel],
            release_specific_enabled: false,
            core_enabled: false,
            active: false
          )
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
