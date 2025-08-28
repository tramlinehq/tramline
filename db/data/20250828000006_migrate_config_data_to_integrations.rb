class MigrateConfigDataToIntegrations < ActiveRecord::Migration[7.2]
  def up
    # Migrate Firebase configs
    execute <<-SQL
      UPDATE google_firebase_integrations 
      SET 
        android_config = app_configs.firebase_android_config,
        ios_config = app_configs.firebase_ios_config
      FROM app_configs, integrations
      WHERE integrations.providable_id = google_firebase_integrations.id
        AND integrations.providable_type = 'GoogleFirebaseIntegration'
        AND integrations.integrable_id = app_configs.app_id
        AND integrations.integrable_type = 'App'
        AND (app_configs.firebase_android_config IS NOT NULL OR app_configs.firebase_ios_config IS NOT NULL);
    SQL

    # Migrate Bugsnag configs
    execute <<-SQL
      UPDATE bugsnag_integrations 
      SET 
        android_config = app_configs.bugsnag_android_config,
        ios_config = app_configs.bugsnag_ios_config
      FROM app_configs, integrations
      WHERE integrations.providable_id = bugsnag_integrations.id
        AND integrations.providable_type = 'BugsnagIntegration'
        AND integrations.integrable_id = app_configs.app_id
        AND integrations.integrable_type = 'App'
        AND (app_configs.bugsnag_android_config IS NOT NULL OR app_configs.bugsnag_ios_config IS NOT NULL);
    SQL

    # Migrate code repository configs to GitHub
    execute <<-SQL
      UPDATE github_integrations 
      SET repository_config = app_configs.code_repository
      FROM app_configs, integrations
      WHERE integrations.providable_id = github_integrations.id
        AND integrations.providable_type = 'GithubIntegration'
        AND integrations.integrable_id = app_configs.app_id
        AND integrations.integrable_type = 'App'
        AND app_configs.code_repository IS NOT NULL;
    SQL

    # Migrate code repository configs to GitLab
    execute <<-SQL
      UPDATE gitlab_integrations 
      SET repository_config = app_configs.code_repository
      FROM app_configs, integrations
      WHERE integrations.providable_id = gitlab_integrations.id
        AND integrations.providable_type = 'GitlabIntegration'
        AND integrations.integrable_id = app_configs.app_id
        AND integrations.integrable_type = 'App'
        AND app_configs.code_repository IS NOT NULL;
    SQL

    # Migrate code repository configs and workspace to Bitbucket
    execute <<-SQL
      UPDATE bitbucket_integrations 
      SET 
        repository_config = app_configs.code_repository,
        workspace = app_configs.bitbucket_workspace
      FROM app_configs, integrations
      WHERE integrations.providable_id = bitbucket_integrations.id
        AND integrations.providable_type = 'BitbucketIntegration'
        AND integrations.integrable_id = app_configs.app_id
        AND integrations.integrable_type = 'App'
        AND (app_configs.code_repository IS NOT NULL OR app_configs.bitbucket_workspace IS NOT NULL);
    SQL

    # Migrate Bitrise project configs
    execute <<-SQL
      UPDATE bitrise_integrations 
      SET project_config = app_configs.bitrise_project_id
      FROM app_configs, integrations
      WHERE integrations.providable_id = bitrise_integrations.id
        AND integrations.providable_type = 'BitriseIntegration'
        AND integrations.integrable_id = app_configs.app_id
        AND integrations.integrable_type = 'App'
        AND app_configs.bitrise_project_id IS NOT NULL;
    SQL

    # Migrate Jira configs
    execute <<-SQL
      UPDATE jira_integrations 
      SET project_config = app_configs.jira_config
      FROM app_configs, integrations
      WHERE integrations.providable_id = jira_integrations.id
        AND integrations.providable_type = 'JiraIntegration'
        AND integrations.integrable_id = app_configs.app_id
        AND integrations.integrable_type = 'App'
        AND app_configs.jira_config IS NOT NULL
        AND app_configs.jira_config != '{}'::jsonb;
    SQL

    # Migrate Linear configs
    execute <<-SQL
      UPDATE linear_integrations 
      SET team_config = app_configs.linear_config
      FROM app_configs, integrations
      WHERE integrations.providable_id = linear_integrations.id
        AND integrations.providable_type = 'LinearIntegration'
        AND integrations.integrable_id = app_configs.app_id
        AND integrations.integrable_type = 'App'
        AND app_configs.linear_config IS NOT NULL
        AND app_configs.linear_config != '{}'::jsonb;
    SQL
  end

  def down
    # This migration is not easily reversible since we're moving data from one table to multiple tables
    # In a real scenario, you might want to create a backup strategy
    raise ActiveRecord::IrreversibleMigration
  end
end