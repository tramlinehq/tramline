class AddRepositoryConfigToVcsIntegrations < ActiveRecord::Migration[7.2]
  def change
    add_column :github_integrations, :repository_config, :jsonb
    add_column :gitlab_integrations, :repository_config, :jsonb
    add_column :bitbucket_integrations, :repository_config, :jsonb
    add_column :bitbucket_integrations, :workspace, :string
  end
end