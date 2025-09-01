class RemoveMigratedColumnsFromAppConfigs < ActiveRecord::Migration[7.2]
  def change
    remove_column :app_configs, :firebase_android_config, :jsonb
    remove_column :app_configs, :firebase_ios_config, :jsonb
    remove_column :app_configs, :bugsnag_android_config, :jsonb
    remove_column :app_configs, :bugsnag_ios_config, :jsonb
    remove_column :app_configs, :code_repository, :json
    remove_column :app_configs, :bitrise_project_id, :jsonb
    remove_column :app_configs, :bitbucket_workspace, :string
    remove_column :app_configs, :jira_config, :jsonb
    remove_column :app_configs, :linear_config, :jsonb
  end
end