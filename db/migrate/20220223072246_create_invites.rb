class CreateInvites < ActiveRecord::Migration[7.0]
  def change
    create_table :invites, id: :uuid do |t|
      t.belongs_to :organization, null: false, index: true, foreign_key: true, type: :uuid
      t.references :sender,
                   foreign_key: { to_table: :users }, null: false, index: true, type: :uuid
      t.references :recipient,
                   foreign_key: { to_table: :users }, index: true, type: :uuid

      t.string :email
      t.string :token
      t.string :role
      t.datetime :accepted_at

      t.timestamps
    end
  end
end
