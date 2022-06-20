class AddBranchingStrategyToTrains < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :branching_strategy, :string
  end
end
