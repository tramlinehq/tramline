class AddStagedRolloutConfigToDeployment < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :deployments, bulk: true do |t|
        t.column :staged_rollout_config, :decimal, array: true, default: []
        t.column :is_staged_rollout, :boolean, default: false
      end
    end
  end
end
