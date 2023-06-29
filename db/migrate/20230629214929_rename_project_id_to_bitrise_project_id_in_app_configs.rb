class RenameProjectIdToBitriseProjectIdInAppConfigs < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      rename_column :app_configs, :project_id, :bitrise_project_id
    end
  end
end
