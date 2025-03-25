class AddExternaBuildNumberToWorkflowRuns < ActiveRecord::Migration[7.2]
  def change
    add_column :workflow_runs, :external_unique_number, :string
  end
end
