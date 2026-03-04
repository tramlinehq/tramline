class ValidateForeignKeyForwardMergeOnPullRequests < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :pull_requests, :forward_merges
  end
end
