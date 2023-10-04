# frozen_string_literal: true

class AddNotificationSettingsForTrains < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      Train.where.not(notification_channel: nil).each do |train|
        train.create_default_notification_settings
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
