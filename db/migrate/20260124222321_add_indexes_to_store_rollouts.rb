class AddIndexesToStoreRollouts < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :store_rollouts, :status, algorithm: :concurrently
    add_index :store_rollouts, :is_staged_rollout, algorithm: :concurrently
    add_index :store_rollouts, :automatic_rollout, algorithm: :concurrently
  end
end
