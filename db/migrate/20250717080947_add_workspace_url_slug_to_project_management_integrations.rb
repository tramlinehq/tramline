class AddWorkspaceUrlSlugToProjectManagementIntegrations < ActiveRecord::Migration[7.2]
  def change
    add_column :jira_integrations, :organization_url, :string
    add_column :linear_integrations, :workspace_url_key, :string
  end
end
