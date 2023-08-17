class AddAutoDeploymentFlagForSteps < ActiveRecord::Migration[7.0]
  def change
    add_column :steps, :auto_deploy, :boolean, default: true
  end
end
