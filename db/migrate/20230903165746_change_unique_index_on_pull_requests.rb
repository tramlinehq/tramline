class ChangeUniqueIndexOnPullRequests < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_index :pull_requests, name: "idx_prs_on_train_group_run_id_and_head_ref_and_base_ref", if_exists: true
      add_index :pull_requests, [:release_id, :phase, :number], unique: true, name: "idx_prs_on_release_id_and_phase_and_number"
    end
  end
end
