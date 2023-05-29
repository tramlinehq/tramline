class PruneNotificationChannelAttributesInAppConfig < ActiveRecord::Migration[7.0]
  def up
    AppConfig.where.not(notification_channel: nil).each do |app_config|
      app_config.notification_channel = app_config.notification_channel.slice("id", "name", "is_private")
      app_config.save
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
