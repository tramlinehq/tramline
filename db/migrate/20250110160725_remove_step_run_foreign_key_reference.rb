class RemoveStepRunForeignKeyReference < ActiveRecord::Migration[7.2]
  def change
    remove_foreign_key :external_builds, :step_runs
    remove_foreign_key :build_artifacts, :step_runs
  end
end
