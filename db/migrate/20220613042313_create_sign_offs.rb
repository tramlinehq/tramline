class CreateSignOffs < ActiveRecord::Migration[7.0]
  def change
    create_table :sign_offs, id: :uuid do |t|
      t.references :sign_off_group, null: false, foreign_key: true, type: :uuid
      t.references :train_steps, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.boolean :signed, null: false, default: false

      t.timestamps
    end
  end
end
