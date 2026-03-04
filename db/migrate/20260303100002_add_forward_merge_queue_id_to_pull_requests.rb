class AddForwardMergeQueueIdToPullRequests < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :pull_requests, :forward_merge_queue, type: :uuid, index: {algorithm: :concurrently}
  end
end
