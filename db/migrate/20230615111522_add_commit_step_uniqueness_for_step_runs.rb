class AddCommitStepUniquenessForStepRuns < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_index :step_runs, [:step_id, :commit_id], unique: true, algorithm: :concurrently
    end
  end

  def down
    remove_index :step_runs, columns: [:step_id, :commit_id]
  end
end
