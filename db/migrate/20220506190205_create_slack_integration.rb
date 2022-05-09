class CreateSlackIntegration < ActiveRecord::Migration[7.0]
  def change
    create_table :slack_integrations, id: :uuid do |t|
      t.string :oauth_access_token
      t.string :original_oauth_access_token

      t.timestamps
    end
  end
end
