class AddWorkspaceNameToLinearIntegrations < ActiveRecord::Migration[7.2]
  def change
    add_column :linear_integrations, :workspace_name, :string
  end
end
