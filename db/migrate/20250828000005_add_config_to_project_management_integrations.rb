class AddConfigToProjectManagementIntegrations < ActiveRecord::Migration[7.2]
  def change
    add_column :jira_integrations, :project_config, :jsonb, default: {}, null: false
    add_column :linear_integrations, :team_config, :jsonb, default: {}, null: false
  end
end