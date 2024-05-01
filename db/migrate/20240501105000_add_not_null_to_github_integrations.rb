class AddNotNullToGithubIntegrations < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_column_null :github_integrations, :installation_id, false
    end
  end
end
