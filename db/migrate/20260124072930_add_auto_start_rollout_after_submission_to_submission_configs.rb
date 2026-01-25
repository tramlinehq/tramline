class AddAutoStartRolloutAfterSubmissionToSubmissionConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :submission_configs, :auto_start_rollout_after_submission, :boolean, default: false, null: false
  end
end
