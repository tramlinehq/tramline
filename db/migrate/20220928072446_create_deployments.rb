class CreateDeployments < ActiveRecord::Migration[7.0]
  def change
    create_table :deployments, id: :uuid do |t|
      t.belongs_to :integration, null: true, index: true, type: :uuid
      t.belongs_to :train_step, null: false, index: true, foreign_key: true, type: :uuid
      t.jsonb :build_artifact_channel
      t.integer :deployment_number, default: 0, null: false, limit: 2 # smallint
      t.index [:deployment_number, :train_step_id], unique: true
      t.index [:build_artifact_channel, :integration_id, :train_step_id], name: "idx_deployments_on_build_artifact_chan_and_integration_and_step", unique: true
      t.timestamps
    end
  end
end
