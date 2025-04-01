class AddAutomaticRolloutColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :store_rollouts, :automatic_rollout, :boolean, null: false, default: false
    add_column :submission_configs, :automatic_rollout, :boolean, null: false, default: false
  end
end
