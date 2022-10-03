class AddUniqueDeploymentNumberPerDeploymentStep < ActiveRecord::Migration[7.0]
  def change
    add_index :deployments, [:deployment_number, :train_step_id], unique: true
  end
end
