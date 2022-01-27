class CreateReleaseTrainStepRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :release_train_step_runs, id: :uuid do |t|
      t.belongs_to :release_train_step, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :release_train_run, null: false, index: true, foreign_key: true, type: :uuid

      t.references :previous_step_run,
        foreign_key: {to_table: :release_train_step_runs}, index: true, type: :uuid

      t.timestamp :scheduled_at, null: false
      t.timestamp :was_run_at

      t.string :status, null: false

      t.timestamps
    end
  end
end
