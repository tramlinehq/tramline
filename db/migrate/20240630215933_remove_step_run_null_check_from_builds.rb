class RemoveStepRunNullCheckFromBuilds < ActiveRecord::Migration[7.0]
  def change
    change_column_null :build_artifacts, :step_run_id, true
  end
end
