class AddFlagToCompleteRolloutNextReleaseInConfigSubmission < ActiveRecord::Migration[7.2]
  def change
    add_column :submission_configs, :finish_rollout_in_next_release, :boolean, default: false, null: false
  end
end
