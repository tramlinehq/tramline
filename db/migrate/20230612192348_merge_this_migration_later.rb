class MergeThisMigrationLater < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_index :releases_commits, column: [:commit_hash, :train_run_id]
      add_index :releases_commits, [:commit_hash, :train_group_run_id], unique: true
      remove_index :releases_pull_requests, name: "idx_prs_on_train_run_id_and_head_ref_and_base_ref", if_exists: true
      add_index :releases_pull_requests, [:train_group_run_id, :head_ref, :base_ref], unique: true, name: "idx_prs_on_train_group_run_id_and_head_ref_and_base_ref"
    end
  end
end
