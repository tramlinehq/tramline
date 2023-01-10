class AddMissingUniqueIndices < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_index :deployment_runs, [:deployment_id, :train_step_run_id], unique: true, algorithm: :concurrently
      add_index :releases_commits, [:commit_hash, :train_run_id], unique: true, algorithm: :concurrently
      add_index :sign_offs, [:releases_commit_id, :train_step_id, :sign_off_group_id], name: "idx_sign_offs_on_commit_step_and_group_id", unique: true, algorithm: :concurrently
    end
  end

  def down
    remove_index :sign_offs, column: [:releases_commit_id, :train_step_id, :sign_off_group_id], name: "idx_sign_offs_on_commit_step_and_group_id", if_exists: true
    remove_index :releases_commits, column: [:commit_hash, :train_run_id]
    remove_index :deployment_runs, column: [:deployment_id, :train_step_run_id]
  end
end
