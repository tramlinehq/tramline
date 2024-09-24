class AddUniqueIndexForCommitInWorkflowRuns < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :workflow_runs, [:pre_prod_release_id, :commit_id], unique: true, algorithm: :concurrently
  end
end
