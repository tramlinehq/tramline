class AddBackmergeStrategyToTrain < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :backmerge_strategy, :string, null: false, default: "on_finalize"
  end
end
