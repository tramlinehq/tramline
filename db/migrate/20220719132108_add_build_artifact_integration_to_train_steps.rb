class AddBuildArtifactIntegrationToTrainSteps < ActiveRecord::Migration[7.0]
  def change
    add_column :train_steps, :build_artifact_integration, :string
  end
end
