class CreateMemberships < ActiveRecord::Migration[7.0]
  def change
    create_table :memberships, id: :uuid do |t|
      t.belongs_to :user, index: true, foreign_key: true, type: :uuid
      t.belongs_to :organization, index: true, foreign_key: true, type: :uuid
      t.string :role, length: 15, null: false

      t.timestamps
    end

    add_index :memberships, [:user_id, :organization_id, :role], unique: true
    add_index :memberships, :role
  end
end
