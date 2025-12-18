class AddProjectConfigToBitriseIntegration < ActiveRecord::Migration[7.2]
  def change
    add_column :bitrise_integrations, :project_config, :jsonb
  end
end
