class RemoveBuildNumberFromWorkflowRuns < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :workflow_runs, :build_number, :string }
  end
end
