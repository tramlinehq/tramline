class AddCommitToTrainStepRuns < ActiveRecord::Migration[7.0]
  def up
    add_reference :train_step_runs, :releases_commit, null: true, foreign_key: true, type: :uuid
    execute <<-SQL.squish
      UPDATE train_step_runs SET releases_commit_id = (SELECT id from releases_commits LIMIT 1) 
    SQL

    change_column_null :train_step_runs, :releases_commit_id, false
  end

  def down
    remove_reference :train_step_runs, :releases_commit
  end
end
