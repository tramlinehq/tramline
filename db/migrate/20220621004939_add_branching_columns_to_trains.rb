class AddBranchingColumnsToTrains < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :release_branch, :string
    add_column :trains, :release_backmerge_branch, :string
  end
end
