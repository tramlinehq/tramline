class CreateSvixIntegrations < ActiveRecord::Migration[7.2]
  def change
    create_table :svix_integrations, id: :uuid do |t|
      t.string :app_id
      t.string :app_name
      t.string :status, default: 'active'

      t.timestamps
    end

    add_index :svix_integrations, :app_id, unique: true
    add_index :svix_integrations, :status
  end
end
