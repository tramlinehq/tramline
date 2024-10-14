class MakeAppIdNullableInIntegrations < ActiveRecord::Migration[7.2]
  def change
    change_column_null :integrations, :app_id, true
  end
end
