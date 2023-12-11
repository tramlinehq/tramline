class AddExternalBuildsForStepRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :external_builds, id: :uuid do |t|
      t.belongs_to :step_run, null: false, index: false, foreign_key: true, type: :uuid

      t.jsonb :metadata, null: false
      t.timestamps
    end

    safety_assured do
      add_index :external_builds, :step_run_id, unique: true
      add_index :step_runs, [:build_number, :build_version]
    end
  end
end
