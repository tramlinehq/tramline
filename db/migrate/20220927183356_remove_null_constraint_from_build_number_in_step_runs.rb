class RemoveNullConstraintFromBuildNumberInStepRuns < ActiveRecord::Migration[7.0]
  def change
    change_column_null(:train_step_runs, :build_number, true)
  end
end
