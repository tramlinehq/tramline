class AddBranchNameToTrainRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :train_runs, :branch_name, :string, null: false
  end
end
