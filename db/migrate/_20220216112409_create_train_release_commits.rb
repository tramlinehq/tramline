class CreateTrainReleaseCommits < ActiveRecord::Migration[7.0]
  def change
    create_table :train_release_commits, id: :uuid do |t|
      t.belongs_to :train_release, null: false, index: true, foreign_key: true, type: :uuid
      t.text :message
      t.string :sha
      t.boolean :detached, default: false, null: false
      t.datetime :authored_at, null: false
      t.datetime :committed_at, null: false

      t.timestamps
    end
  end
end
