class AddSignRequiredToTrainStepRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :train_step_runs, :sign_required, :boolean, default: true
  end
end
