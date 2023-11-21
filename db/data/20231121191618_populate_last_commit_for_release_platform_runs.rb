# frozen_string_literal: true

class PopulateLastCommitForReleasePlatformRuns < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      ReleasePlatformRun.all.each do |prun|
        prun.update!(last_commit: prun.step_runs.flat_map(&:commit).max_by(&:timestamp))
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
