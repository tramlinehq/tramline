class AddMetadataToIntegrations < ActiveRecord::Migration[7.0]
  def change
    add_column :integrations, :metadata, :jsonb
  end
end
