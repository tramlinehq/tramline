class CreateAccountsCustomStorages < ActiveRecord::Migration[7.0]
  def change
    create_table :accounts_custom_storages, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: {to_table: :organizations}, type: :uuid, index: {unique: true}
      t.string :bucket, null: false
      t.string :project_id, null: false
      t.jsonb :credentials, null: false

      t.timestamps
    end
  end
end
