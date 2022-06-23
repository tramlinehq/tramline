class CreateReleasesCommitListners < ActiveRecord::Migration[7.0]
  def change
    create_table :releases_commit_listners, id: :uuid do |t|
      t.references :train, null: false, foreign_key: true, type: :uuid
      t.string :branch_name, null: false

      t.timestamps
    end
  end
end
