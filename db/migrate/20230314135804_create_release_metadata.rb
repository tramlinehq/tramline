class CreateReleaseMetadata < ActiveRecord::Migration[7.0]
  def change
    create_table :release_metadata, id: :uuid do |t|
      t.belongs_to :train_run, null: false, index: true, foreign_key: true, type: :uuid

      t.string :locale, null: false
      t.text :release_notes
      t.text :promo_text

      t.timestamps
    end

    add_index :release_metadata, [:train_run_id, :locale], unique: true
  end
end
