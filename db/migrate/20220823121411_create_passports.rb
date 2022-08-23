class CreatePassports < ActiveRecord::Migration[7.0]
  def change
    create_table :passports, id: :uuid do |t|
      t.references :stampable, polymorphic: true, index: true, null: false, type: :uuid
      t.string :reason
      t.string :kind
      t.string :message
      t.json :metadata
      t.uuid :user_id

      t.timestamps
    end

    add_index :passports, :reason
    add_index :passports, :kind
  end
end
