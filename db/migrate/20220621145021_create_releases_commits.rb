class CreateReleasesCommits < ActiveRecord::Migration[7.0]
  def change
    create_table :releases_commits, id: :uuid do |t|
      t.string :commit_hash, null: false
      t.references :train, null: false, foreign_key: true, type: :uuid
      t.string :message
      t.datetime :timestamp, null: false
      t.string :author_name, null: false
      t.string :author_email, null: false
      t.string :url

      t.timestamps
    end
  end
end
