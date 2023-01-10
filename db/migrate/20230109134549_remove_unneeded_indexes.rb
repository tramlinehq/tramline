class RemoveUnneededIndexes < ActiveRecord::Migration[7.0]
  def change
    remove_index :memberships, name: "index_memberships_on_user_id", column: :user_id
    remove_index :releases_pull_requests, name: "index_releases_pull_requests_on_train_run_id", column: :train_run_id
    remove_index :deployment_runs, name: "index_deployment_runs_on_deployment_id", column: :deployment_id
    remove_index :sign_offs, name: "index_sign_offs_on_releases_commit_id", column: :releases_commit_id
  end
end
