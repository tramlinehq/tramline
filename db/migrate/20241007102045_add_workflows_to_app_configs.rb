class AddWorkflowsToAppConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :app_configs, :ci_cd_workflows, :jsonb, default: nil
  end
end
