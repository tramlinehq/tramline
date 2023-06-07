class AddCommitLogToRelease < ActiveRecord::Migration[7.0]
  def change
    create_table :release_commit_logs, id: :uuid do |t|
      t.belongs_to :train_run, null: false, index: true, foreign_key: true, type: :uuid
      t.string :from, null: false
      t.jsonb :commits

      t.timestamps
    end
  end
end
