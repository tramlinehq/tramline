class AddPullRequestsToCommits < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_reference :pull_requests, :commit, null: true, foreign_key: false, type: :uuid, index: {algorithm: :concurrently}
  end
end
