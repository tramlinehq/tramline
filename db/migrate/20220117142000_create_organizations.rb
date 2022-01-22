class CreateOrganizations < ActiveRecord::Migration[7.0]
  def change
    create_table :organizations, id: :uuid do |t|
      t.string :status, null: false
      t.string :name, null: false
      t.string :slug
      t.string :created_by, null: false

      t.timestamps
    end

    add_index :organizations, :slug, unique: true
    add_index :organizations, :status
  end
end
