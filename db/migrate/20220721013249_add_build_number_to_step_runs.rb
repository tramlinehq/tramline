class AddBuildNumberToStepRuns < ActiveRecord::Migration[7.0]
  def up
    add_column :train_step_runs, :build_number, :string

    execute <<-SQL.squish
      UPDATE train_step_runs SET build_number = 1
    SQL

    change_column_null :train_step_runs, :build_number, false
  end

  def down
    remove_column :train_step_runs, :build_number
  end
end
