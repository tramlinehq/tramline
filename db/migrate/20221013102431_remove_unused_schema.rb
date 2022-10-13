class RemoveUnusedSchema < ActiveRecord::Migration[7.0]
  def change
    drop_table :release_situations
    remove_column :train_step_runs, :previous_step_run_id
    remove_index :train_step_runs, name: "index_train_step_runs_on_previous_step_run_id"
    remove_column :train_runs, :previous_train_run
    remove_index :train_runs, name: "index_train_runs_on_code_name_and_train_id"
  end
end
