class ChangeBuildArtifactChannelInStep < ActiveRecord::Migration[7.0]
  def up
    change_column :train_steps, :build_artifact_integration, :string, null: true
    change_column :train_steps, :build_artifact_channel, :json, null: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
