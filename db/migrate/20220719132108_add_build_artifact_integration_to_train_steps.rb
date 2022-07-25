class AddBuildArtifactIntegrationToTrainSteps < ActiveRecord::Migration[7.0]
  def up
    add_column :train_steps, :build_artifact_integration, :string
    execute <<-SQL.squish
      UPDATE train_steps SET build_artifact_integration = 'SlackIntegration'
    SQL

    change_column_null :train_steps, :build_artifact_integration, false
  end

  def down
    remove_column :train_steps, :build_artifact_integration, :string
  end
end
