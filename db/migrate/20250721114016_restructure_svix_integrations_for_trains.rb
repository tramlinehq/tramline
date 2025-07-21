class RestructureSvixIntegrationsForTrains < ActiveRecord::Migration[7.2]
  def change
    # Drop existing table and recreate with proper structure
    drop_table :svix_integrations, if_exists: true
    
    # Remove any existing indexes that might conflict
    safety_assured do
      execute "DROP INDEX IF EXISTS index_svix_integrations_on_train_id"
      execute "DROP INDEX IF EXISTS index_svix_integrations_on_app_id"
      execute "DROP INDEX IF EXISTS index_svix_integrations_on_status"
    end
    
    create_table :svix_integrations do |t|
      t.references :train, null: false, foreign_key: true, type: :uuid, index: {unique: true}
      t.string :app_id
      t.string :app_name
      t.string :status, default: 'active'

      t.timestamps
    end

    add_index :svix_integrations, :app_id, unique: true
    add_index :svix_integrations, :status
  end
end
