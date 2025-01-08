class CreateJiraIntegrations < ActiveRecord::Migration[7.2]
  def change
    create_table :jira_integrations, id: :uuid do |t|
      t.string :oauth_access_token
      t.string :oauth_refresh_token
      t.string :cloud_id

      t.timestamps
    end

    add_index :jira_integrations, :cloud_id
  end
end
