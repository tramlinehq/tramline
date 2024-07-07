class AddStagedRolloutFlagToStoreRollout < ActiveRecord::Migration[7.0]
  def change
    add_column :store_rollouts, :is_staged_rollout, :boolean, default: false
  end
end
