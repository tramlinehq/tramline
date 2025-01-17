class RemoveStepAndDeploymentForeignKeys < ActiveRecord::Migration[7.2]
  def change
    remove_foreign_key :release_health_events, :deployment_runs
    remove_foreign_key :release_health_metrics, :deployment_runs
  end
end
