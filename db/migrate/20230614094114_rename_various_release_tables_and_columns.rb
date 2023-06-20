class RenameVariousReleaseTablesAndColumns < ActiveRecord::Migration[7.0]
  def change
    drop_table :sign_offs, if_exists: true
    drop_table :sign_off_group_memberships, if_exists: true
    drop_table :train_sign_off_groups, if_exists: true
    drop_table :sign_off_groups, if_exists: true

    safety_assured do
      rename_table :trains, :release_platforms
      rename_table :train_groups, :trains
      rename_table :train_runs, :release_platform_runs
      rename_table :train_group_runs, :releases
      rename_table :train_steps, :steps
      rename_table :train_step_runs, :step_runs
      rename_table :releases_commits, :commits
      rename_table :releases_commit_listeners, :commit_listeners
      rename_table :releases_pull_requests, :pull_requests

      rename_column :release_platforms, :train_group_id, :train_id

      rename_column :release_platform_runs, :train_id, :release_platform_id
      rename_column :release_platform_runs, :train_group_run_id, :release_id

      rename_column :releases, :train_group_id, :train_id

      rename_column :steps, :train_id, :release_platform_id

      rename_column :step_runs, :train_step_id, :step_id
      rename_column :step_runs, :train_run_id, :release_platform_run_id
      rename_column :step_runs, :releases_commit_id, :commit_id

      rename_column :commits, :train_id, :release_platform_id
      rename_column :commits, :train_run_id, :release_platform_run_id
      rename_column :commits, :train_group_run_id, :release_id

      rename_column :commit_listeners, :train_id, :release_platform_id
      rename_column :commit_listeners, :train_group_id, :train_id

      rename_column :pull_requests, :train_run_id, :release_platform_run_id
      rename_column :pull_requests, :train_group_run_id, :release_id

      rename_column :build_artifacts, :train_step_runs_id, :step_run_id
      rename_column :deployments, :train_step_id, :step_id
      rename_column :deployment_runs, :train_step_run_id, :step_run_id

      rename_column :release_metadata, :train_run_id, :release_platform_run_id
      rename_column :release_metadata, :train_group_run_id, :release_id
    end
  end
end
