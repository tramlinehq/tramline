class AddDeploymentChannelToStoreSubmissions < ActiveRecord::Migration[7.0]
  def change
    add_column :store_submissions, :deployment_channel, :jsonb, null: true
    safety_assured { remove_column :store_rollouts, :release_channel, :jsonb }
  end
end
