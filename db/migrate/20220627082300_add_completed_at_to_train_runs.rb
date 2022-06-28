class AddCompletedAtToTrainRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :train_runs, :completed_at, :datetime
  end
end
