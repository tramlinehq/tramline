class AddCiRefToTrainStepRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :train_step_runs, :ci_ref, :string
    add_column :train_step_runs, :ci_link, :string
  end
end
