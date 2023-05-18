class AddWebhookIdInTrains < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :vcs_webhook_id, :string
  end
end
