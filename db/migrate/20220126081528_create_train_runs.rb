class CreateTrainRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :train_runs, id: :uuid do |t|
      t.belongs_to :train, null: false, index: true, foreign_key: true, type: :uuid
      t.references :previous_train_run,
                   foreign_key: { to_table: :train_runs }, index: true, type: :uuid

      t.string :code_name, null: false

      t.timestamp :scheduled_at, null: false
      t.timestamp :was_run_at
      t.string :commit_sha

      t.string :status, null: false

      t.timestamps
    end

    add_index :train_runs, [:code_name, :train_id], unique: true
  end
end
