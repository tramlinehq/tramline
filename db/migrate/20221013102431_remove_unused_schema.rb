class RemoveUnusedSchema < ActiveRecord::Migration[7.0]
  def change
    drop_table :release_situations, if_exists: true
    remove_column :train_step_runs, :previous_step_run_id, :uuid
    remove_index :train_step_runs, name: "index_train_step_runs_on_previous_step_run_id", if_exists: true
    remove_column :train_runs, :previous_train_run_id, :uuid
    remove_index :train_runs, name: "index_train_runs_on_code_name_and_train_id", if_exists: true
    remove_column :train_runs, :was_run_at, :datetime
    remove_column :train_step_runs, :was_run_at, :datetime
  end
end
