class RemoveInitialRolloutPercentageFromStepRun < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_column :train_step_runs, :initial_rollout_percentage, :decimal, precision: 8, scale: 5, null: true
    end
  end
end
