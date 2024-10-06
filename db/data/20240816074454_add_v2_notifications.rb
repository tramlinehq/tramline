# frozen_string_literal: true

class AddV2Notifications < ActiveRecord::Migration[7.0]
  def up
    return

    ActiveRecord::Base.transaction do
      Train.all.where.not(notification_channel: nil).each do |train|
        next if train.notification_settings.empty?

        vals = NotificationSetting::V2_KINDS.map do |_, kind|
          {
            train_id: train.id,
            kind:,
            active: true,
            notification_channels: [train.notification_channel]
          }
        end
        NotificationSetting.upsert_all(vals, unique_by: [:train_id, :kind])
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
