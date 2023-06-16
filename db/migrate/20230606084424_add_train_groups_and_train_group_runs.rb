class AddTrainGroupsAndTrainGroupRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :train_groups, id: :uuid do |t|
      t.belongs_to :app, null: false, foreign_key: true, type: :uuid

      t.string :name, null: false
      t.string :description
      t.string :status, null: false
      t.string :branching_strategy, null: false
      t.string :release_branch
      t.string :release_backmerge_branch
      t.string :working_branch
      t.string :vcs_webhook_id
      t.string :slug
      t.string :version_seeded_with
      t.string :version_current

      t.timestamps
    end

    create_table :train_group_runs, id: :uuid do |t|
      t.belongs_to :train_group, null: false, foreign_key: true, type: :uuid

      t.string :branch_name, null: false
      t.string :status, null: false
      t.string :original_release_version
      t.string :release_version
      t.timestamp :scheduled_at
      t.timestamp :completed_at
      t.timestamp :stopped_at

      t.timestamps
    end

    add_column :trains, :train_group_id, :uuid, null: true
    add_column :train_runs, :train_group_run_id, :uuid, null: true
    add_column :releases_commits, :train_group_run_id, :uuid, null: true
    add_column :release_metadata, :train_group_run_id, :uuid, null: true
    add_column :releases_pull_requests, :train_group_run_id, :uuid, null: true
    add_column :releases_commit_listeners, :train_group_id, :uuid, null: true

    change_column_null :release_metadata, :train_run_id, true
    change_column_null :releases_pull_requests, :train_run_id, true
    change_column_null :releases_commit_listeners, :train_id, true
    change_column_null :releases_commits, :train_run_id, true
    change_column_null :releases_commits, :train_id, true
  end
end
