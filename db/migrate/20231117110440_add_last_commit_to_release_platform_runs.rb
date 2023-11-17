class AddLastCommitToReleasePlatformRuns < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      add_reference :release_platform_runs, :last_commit, type: :uuid, foreign_key: {to_table: :commits}, null: true
      ReleasePlatformRun.all.each do |prun|
        prun.update!(last_commit: prun.step_runs.flat_map(&:commit).max_by(&:timestamp))
      end
    end
  end
end
