class AddStoppedAtToTrainRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :train_runs, :stopped_at, :datetime
  end
end
