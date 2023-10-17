class AddBugsnagProjectIdToAppConfig < ActiveRecord::Migration[7.0]
  def change
    add_column :app_configs, :bugsnag_project_id, :jsonb
  end
end
