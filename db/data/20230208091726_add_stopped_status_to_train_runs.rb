class AddStoppedStatusToTrainRuns < ActiveRecord::Migration[7.0]
  def up
    ReleasePlatformRun
      .where(completed_at: nil, status: "finished")
      .update_all("stopped_at = updated_at, status = 'stopped'")
  end

  def down
    ReleasePlatformRun
      .where(status: "stopped")
      .update_all("completed_at = NULL, status = 'finished'")
  end
end
