class AddCompletedAtToStoreRollouts < ActiveRecord::Migration[7.0]
  def change
    add_column :store_rollouts, :completed_at, :datetime
  end
end
