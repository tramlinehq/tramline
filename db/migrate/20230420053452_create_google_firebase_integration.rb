class CreateGoogleFirebaseIntegration < ActiveRecord::Migration[7.0]
  def change
    create_table :google_firebase_integrations, id: :uuid do |t|
      t.string :json_key
      t.string :original_json_key
      t.string :project_number
      t.string :app_id

      t.timestamps
    end
  end
end
