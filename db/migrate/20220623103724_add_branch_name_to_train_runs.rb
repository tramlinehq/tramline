class AddBranchNameToTrainRuns < ActiveRecord::Migration[7.0]
  def up
    add_column :train_runs, :branch_name, :string

    execute <<-SQL
      UPDATE train_runs SET branch_name = ' '
    SQL

    change_column_null :train_runs, :branch_name, false
  end

  def down
    remove_column :train_runs, :branch_name, :string
  end
end
