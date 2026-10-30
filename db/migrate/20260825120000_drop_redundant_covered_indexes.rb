class DropRedundantCoveredIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  # Each of these single-column indexes is redundant: its column is the leading
  # column of an existing composite index, which already serves the same lookups.
  # Dropping them speeds up writes and reclaims space. Flagged by pgHero.
  #
  # if_exists: true keeps this idempotent -- some of these may already have been
  # dropped directly on prod during the pgHero cleanup, and the migration must
  # not fail the deploy in that case.
  def change
    remove_index :notification_settings, :train_id,
      name: "index_notification_settings_on_train_id", algorithm: :concurrently, if_exists: true

    remove_index :pre_prod_releases, :release_platform_run_id,
      name: "index_pre_prod_releases_on_release_platform_run_id", algorithm: :concurrently, if_exists: true

    remove_index :release_health_metrics, :production_release_id,
      name: "index_release_health_metrics_on_production_release_id", algorithm: :concurrently, if_exists: true

    remove_index :release_metadata, :release_platform_run_id,
      name: "index_release_metadata_on_release_platform_run_id", algorithm: :concurrently, if_exists: true

    remove_index :step_runs, :step_id,
      name: "index_step_runs_on_step_id", algorithm: :concurrently, if_exists: true

    remove_index :submission_configs, :release_step_config_id,
      name: "index_submission_configs_on_release_step_config_id", algorithm: :concurrently, if_exists: true

    remove_index :workflow_config_parameters, :workflow_id,
      name: "index_workflow_config_parameters_on_workflow_id", algorithm: :concurrently, if_exists: true

    remove_index :workflow_runs, :pre_prod_release_id,
      name: "index_workflow_runs_on_pre_prod_release_id", algorithm: :concurrently, if_exists: true
  end
end
