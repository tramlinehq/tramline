class AddReleaseBranchPatternToTrains < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :release_branch_pattern, :string
  end
end
