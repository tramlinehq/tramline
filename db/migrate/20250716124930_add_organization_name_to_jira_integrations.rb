class AddOrganizationNameToJiraIntegrations < ActiveRecord::Migration[7.2]
  def change
    add_column :jira_integrations, :organization_name, :string
  end
end
