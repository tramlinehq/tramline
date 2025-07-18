class RenameOrganizationIdToWorkspaceIdInLinearIntegrations < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      rename_column :linear_integrations, :organization_id, :workspace_id
    end
  end
end
