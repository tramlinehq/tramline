class AddForeignKeyForwardMergeQueueToPullRequests < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :pull_requests, :forward_merge_queues, validate: false
  end
end
