class AddExternalBuildMetadataForStepRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :external_build_metadata, id: :uuid do |t|
      t.belongs_to :step_run, null: false, foreign_key: true, type: :uuid

      t.timestamp :added_at, null: false
      t.jsonb :metadata, null: false
      t.timestamps
    end

    safety_assured do
      add_index :external_build_metadata, :step_run_id, unique: true, name: "unique_index_external_build_metadata_on_step_run_id"
      add_index :step_runs, [:build_number, :build_version]
    end
  end
end
