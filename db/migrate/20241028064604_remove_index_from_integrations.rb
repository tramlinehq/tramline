class RemoveIndexFromIntegrations < ActiveRecord::Migration[7.2]
  def change
    remove_index :integrations, name: "index_integrations_on_providable_type_and_providable_id"
  end
end
