# frozen_string_literal: true

class BackfillTrainNotificationChannels < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      Train.where(notification_channel: nil).each do |train|
        train.update!(notification_channel: train.app.config.notification_channel) if train.app.notifications_set_up?
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
