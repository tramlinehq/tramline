class CreateReleaseIndexComponents < ActiveRecord::Migration[7.0]
  def change
    create_table :release_index_components, id: :uuid do |t|
      t.references :release_index, null: false, foreign_key: true, type: :uuid
      t.numrange :tolerable_range, null: false
      t.string :tolerable_unit, null: false
      t.string :name, null: false
      t.decimal :weight, precision: 4, scale: 3, null: false

      t.timestamps
    end

    add_index :release_index_components, [:name, :release_index_id], unique: true
  end
end
