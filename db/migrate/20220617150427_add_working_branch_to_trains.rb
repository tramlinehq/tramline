class AddWorkingBranchToTrains < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :working_branch, :string
  end
end
