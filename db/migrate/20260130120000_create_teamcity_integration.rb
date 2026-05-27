class CreateTeamcityIntegration < ActiveRecord::Migration[7.1]
  def change
    create_table :teamcity_integrations, id: :uuid do |t|
      t.string :server_url, null: false
      t.string :access_token
      t.jsonb :project_config

      # Cloudflare Zero Trust credentials (optional)
      t.string :cf_access_client_id
      t.string :cf_access_client_secret

      t.timestamps
    end
  end
end
