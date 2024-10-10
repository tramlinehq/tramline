class AddUniqueConstraintsToIntegration < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :integrations, [:app_id, :category, :providable_type, :status], unique: true, where: "status = 'connected'", name: "unique_connected_integration_category", algorithm: :concurrently
  end
end
