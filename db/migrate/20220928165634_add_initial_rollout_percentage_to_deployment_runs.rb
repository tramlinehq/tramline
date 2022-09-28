class AddInitialRolloutPercentageToDeploymentRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :deployment_runs, :initial_rollout_percentage, :decimal, precision: 8, scale: 5, null: true
  end
end
