class AddBuildVersionToTrainStepRuns < ActiveRecord::Migration[7.0]
  def up
    add_column :train_step_runs, :build_version, :string
    execute <<-SQL.squish
      UPDATE train_step_runs SET build_version = ''
    SQL

    change_column_null :train_step_runs, :build_version, false
  end

  def down
    remove_column :train_step_runs, :build_version, :string
  end
end
