class AddReleaseSuffixToTrainSteps < ActiveRecord::Migration[7.0]
  def up
    add_column :train_steps, :release_suffix, :string
    execute <<-SQL.squish
      UPDATE train_steps SET release_suffix = ''
    SQL

    change_column_null :train_steps, :release_suffix, false
  end

  def down
    remove_column :train_steps, :release_suffix, :string
  end
end
