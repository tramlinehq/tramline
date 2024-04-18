class AddReleaseHealthNotificationSetting < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      Train.all.where.not(notification_channel: nil).each do |train|
        next if train.notification_settings.empty?

        setting = train.notification_settings.find_by(kind: NotificationSetting.kinds[:release_health_events])
        next if setting.present?

        train.notification_settings.create!(kind: NotificationSetting.kinds[:release_health_events], active: false)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
