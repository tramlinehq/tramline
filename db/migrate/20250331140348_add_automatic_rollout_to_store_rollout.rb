class AddAutomaticRolloutToStoreRollout < ActiveRecord::Migration[7.2]
  def change
    add_column :store_rollouts, :automatic_rollout, :boolean, null: false, default: false
  end
end
