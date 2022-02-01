class CreateApps < ActiveRecord::Migration[7.0]
  def change
    create_table :apps, id: :uuid do |t|
      t.belongs_to :organization, null: false, index: true, foreign_key: true, type: :uuid

      t.string :name, null: false
      t.string :description

      t.string :platform, null: false
      t.string :bundle_identifier, null: false
      t.bigint :build_number, null: false
      t.string :timezone, null: false

      t.string :slug

      t.timestamps
    end

    add_index :apps, [:bundle_identifier, :organization_id], unique: true
  end
end
