class CreateAppStoreIntegration < ActiveRecord::Migration[7.0]
  def change
    create_table :app_store_integrations, id: :uuid do |t|
      t.string :key_id
      t.string :p8_key
      t.string :issuer_id

      t.timestamps
    end
  end
end
