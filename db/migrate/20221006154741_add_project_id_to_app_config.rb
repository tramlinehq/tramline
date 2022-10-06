class AddProjectIdToAppConfig < ActiveRecord::Migration[7.0]
  def change
    add_column :app_configs, :project_id, :jsonb, null: true
  end
end
