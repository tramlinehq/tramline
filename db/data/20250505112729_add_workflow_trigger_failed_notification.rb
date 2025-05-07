# frozen_string_literal: true

class AddWorkflowTriggerFailedNotification < ActiveRecord::Migration[7.2]
  def up
    ActiveRecord::Base.transaction do
      Train.all.where.not(notification_channel: nil).find_each do |train|
        next if train.notification_settings.empty?

        train.notification_settings.create!(
          notification_channels: train.notification_channel,
          kind: NotificationSetting.kinds[:workflow_trigger_failed],
          active: true
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
