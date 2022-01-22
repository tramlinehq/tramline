class CreateApps < ActiveRecord::Migration[7.0]
  def change
    create_table :apps, id: :uuid do |t|
      t.string :name, null: false
      t.string :description
      t.string :bundle_identifier, null: false
      t.belongs_to :organization, index: true, foreign_key: true, type: :uuid
      t.string :slug

      t.timestamps
    end

    add_index :apps, [:organization_id, :bundle_identifier], unique: true
  end
end
