class RemoveDeadColumns < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_column :app_configs, :working_branch, :string
      remove_column :trains, :signoff_enabled, :boolean
      remove_column :train_steps, :build_artifact_integration, :string
      remove_column :train_steps, :build_artifact_channel, :json
    end
  end
end
