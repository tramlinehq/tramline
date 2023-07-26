class AddBuildNotesOnStepRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :step_runs, :build_notes_raw, :text, array: true, default: []
  end
end
