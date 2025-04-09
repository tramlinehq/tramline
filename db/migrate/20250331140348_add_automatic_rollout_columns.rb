class AddAutomaticRolloutColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :store_rollouts, :automatic_rollout, :boolean, null: false, default: false
    add_column :store_rollouts, :automatic_rollout_updated_at, :datetime
    add_column :store_rollouts, :automatic_rollout_next_update_at, :datetime
    add_column :submission_configs, :automatic_rollout, :boolean, default: false
  end
end
