class AddWebhooksEnabledToTrains < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :webhooks_enabled, :boolean, default: false, null: false
  end
end
