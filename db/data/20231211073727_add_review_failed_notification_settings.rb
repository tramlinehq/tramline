# frozen_string_literal: true

class AddReviewFailedNotificationSettings < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      Train.all.where.not(notification_channel: nil).each do |train|
        review_failed_setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:review_failed])
        next if review_failed_setting.present?

        review_approved_setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:review_approved])
        train.notification_settings.create!(
          kind: NotificationSetting.kinds[:review_failed],
          active: review_approved_setting.active,
          notification_channels: review_approved_setting.notification_channels
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
