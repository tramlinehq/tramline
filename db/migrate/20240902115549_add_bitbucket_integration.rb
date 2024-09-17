class AddBitbucketIntegration < ActiveRecord::Migration[7.0]
  def change
    create_table :bitbucket_integrations, id: :uuid do |t|
      t.string :oauth_access_token
      t.string :oauth_refresh_token

      t.timestamps
    end
  end
end
