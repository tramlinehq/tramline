class AddApprovalStatusToTrainStepRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :train_step_runs, :approval_status, :string, default: "pending", null: false
  end
end
