class AddTypeToWorkflowRun < ActiveRecord::Migration[7.0]
  def change
    add_column :workflow_runs, :kind, :string, null: false, default: "release_candidate"
  end
end
