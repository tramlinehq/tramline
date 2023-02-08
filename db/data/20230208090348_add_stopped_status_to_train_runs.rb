class AddStoppedStatusToTrainRuns < ActiveRecord::Migration[7.0]
  def up
    Releases::Train::Run
      .where(completed_at: nil, status: "finished")
      .update_all(status: "stopped")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
