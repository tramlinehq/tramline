class UpdateUniquenessIndexOnIntegrations < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    remove_index :integrations, column: [:app_id, :category, :providable_type, :status], name: "unique_connected_integration_category", algorithm: :concurrently, if_exists: true
    add_index :integrations, [:integrable_id, :category, :providable_type, :status], unique: true, where: "status = 'connected'", name: "unique_connected_integration_category", algorithm: :concurrently
  end
end
