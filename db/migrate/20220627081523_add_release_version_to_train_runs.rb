class AddReleaseVersionToTrainRuns < ActiveRecord::Migration[7.0]
  def up
    add_column :train_runs, :release_version, :string

    execute <<-SQL.squish
      UPDATE train_runs SET release_version = ' '
    SQL

    change_column_null :train_runs, :release_version, false
  end

  def down
    remove_column :train_runs, :release_version, :string
  end
end
