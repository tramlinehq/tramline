class ChangeDiscardedDeploymentBuildArtifactChannelUniqueIndex < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    remove_index :deployments, name: "idx_deployments_on_build_artifact_chan_and_integration_and_step", column: [:integration_id, :build_artifact_channel]
    add_index :deployments, [:build_artifact_channel, :integration_id, :step_id], unique: true, where: "discarded_at IS NULL", name: "idx_kept_deployments_on_artifact_chan_and_integration_and_step", algorithm: :concurrently
  end
end
