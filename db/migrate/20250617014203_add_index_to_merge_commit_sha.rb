class AddIndexToMergeCommitSha < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :pull_requests, :merge_commit_sha, where: "merge_commit_sha IS NOT NULL", algorithm: :concurrently
  end
end
