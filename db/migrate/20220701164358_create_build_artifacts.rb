class CreateBuildArtifacts < ActiveRecord::Migration[7.0]
  def change
    create_table :build_artifacts, id: :uuid do |t|
      t.references :train_step_runs, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end
  end
end
