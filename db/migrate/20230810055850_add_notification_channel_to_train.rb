class AddNotificationChannelToTrain < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :notification_channel, :jsonb, null: true
  end
end
