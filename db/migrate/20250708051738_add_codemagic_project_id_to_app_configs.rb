class AddCodemagicProjectIdToAppConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :app_configs, :codemagic_project_id, :jsonb
  end
end
