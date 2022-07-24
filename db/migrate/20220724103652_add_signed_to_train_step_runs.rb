class AddSignedToTrainStepRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :train_step_runs, :signed, :boolean, default: false, null: false
  end
end
