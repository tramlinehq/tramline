class ValidateForeignKeyForwardMergeQueueOnPullRequests < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :pull_requests, :forward_merge_queues
  end
end
