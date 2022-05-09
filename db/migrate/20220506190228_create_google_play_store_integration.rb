class CreateGooglePlayStoreIntegration < ActiveRecord::Migration[7.0]
  def change
    create_table :google_play_store_integrations, id: :uuid do |t|
      t.string :json_key
      t.string :original_json_key

      t.timestamps
    end
  end
end
