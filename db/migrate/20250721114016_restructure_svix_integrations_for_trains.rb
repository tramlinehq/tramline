class RestructureSvixIntegrationsForTrains < ActiveRecord::Migration[7.2]
  def change
    create_table :svix_integrations, id: :uuid do |t|
      t.references :train, null: false, foreign_key: true, type: :uuid, index: {unique: true}
      t.string :svix_app_id
      t.string :svix_app_name
      t.string :status, default: "inactive"

      t.timestamps
    end

    add_index :svix_integrations, :svix_app_id, unique: true
    add_index :svix_integrations, :status
  end
end
