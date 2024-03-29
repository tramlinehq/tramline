class AddSlackFileIdToStepRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :step_runs, :slack_file_id, :string
  end
end
