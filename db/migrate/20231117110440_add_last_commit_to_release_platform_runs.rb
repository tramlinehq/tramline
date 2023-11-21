class AddLastCommitToReleasePlatformRuns < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_reference :release_platform_runs, :last_commit, type: :uuid, foreign_key: {to_table: :commits}, null: true
    end
  end
end
