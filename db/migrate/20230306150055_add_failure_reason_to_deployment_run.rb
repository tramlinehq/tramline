class AddFailureReasonToDeploymentRun < ActiveRecord::Migration[7.0]
  def change
    add_column :deployment_runs, :failure_reason, :string
  end
end
