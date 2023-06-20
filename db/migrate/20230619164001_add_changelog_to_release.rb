class AddChangelogToRelease < ActiveRecord::Migration[7.0]
  def change
    create_table :release_changelogs, id: :uuid do |t|
      t.belongs_to :release, null: false, index: true, foreign_key: true, type: :uuid
      t.string :from_ref, null: false
      t.jsonb :commits

      t.timestamps
    end
  end
end
