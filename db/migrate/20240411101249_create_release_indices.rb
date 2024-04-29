class CreateReleaseIndices < ActiveRecord::Migration[7.0]
  def change
    create_table :release_indices, id: :uuid do |t|
      t.references :train, null: false, foreign_key: true, type: :uuid
      t.numrange :tolerable_range, null: false

      t.timestamps
    end
  end
end
