class AddMergeCommitShaToPullRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :pull_requests, :merge_commit_sha, :string
  end
end
