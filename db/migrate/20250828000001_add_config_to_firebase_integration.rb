class AddConfigToFirebaseIntegration < ActiveRecord::Migration[7.2]
  def change
    add_column :google_firebase_integrations, :android_config, :jsonb
    add_column :google_firebase_integrations, :ios_config, :jsonb
  end
end