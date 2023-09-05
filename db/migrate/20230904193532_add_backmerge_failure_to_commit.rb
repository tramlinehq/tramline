class AddBackmergeFailureToCommit < ActiveRecord::Migration[7.0]
  def change
    add_column :commits, :backmerge_failure, :boolean, default: false
  end
end
