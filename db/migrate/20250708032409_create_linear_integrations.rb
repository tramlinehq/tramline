class CreateLinearIntegrations < ActiveRecord::Migration[7.2]
  def change
    create_table :linear_integrations, id: :uuid do |t|
      t.string :oauth_access_token
      t.string :oauth_refresh_token
      t.string :organization_id

      t.timestamps
    end

    add_index :linear_integrations, :organization_id
  end
end
