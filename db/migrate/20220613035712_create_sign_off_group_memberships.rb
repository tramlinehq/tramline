class CreateSignOffGroupMemberships < ActiveRecord::Migration[7.0]
  def change
    create_table :sign_off_group_memberships, id: :uuid do |t|
      t.references :sign_off_group, null: false, foreign_key: true, type: :uuid
      t.references :users, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
