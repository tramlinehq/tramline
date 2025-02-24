class RemoveCiCdWorkflowsFromAppConfig < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :app_configs, :ci_cd_workflows, :jsonb }
  end
end
