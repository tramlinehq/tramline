class AddSvixEndpointIdToOutgoingWebhooks < ActiveRecord::Migration[7.2]
  def change
    add_column :outgoing_webhooks, :svix_endpoint_id, :string
  end
end
