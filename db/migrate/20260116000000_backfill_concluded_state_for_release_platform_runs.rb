class BackfillConcludedStateForReleasePlatformRuns < ActiveRecord::Migration[7.1]
  def up
    # Backfill existing finished platform runs where the release is partially_finished
    # These should be marked as concluded instead of finished
    execute <<-SQL.squish
      UPDATE release_platform_runs
      SET status = 'concluded'
      WHERE status = 'finished'
      AND release_id IN (
        SELECT id FROM releases WHERE status = 'partially_finished'
      )
    SQL
  end

  def down
    # Revert concluded back to finished
    execute <<-SQL.squish
      UPDATE release_platform_runs
      SET status = 'finished'
      WHERE status = 'concluded'
    SQL
  end
end
