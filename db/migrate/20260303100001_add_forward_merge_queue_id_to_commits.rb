class AddForwardMergeQueueIdToCommits < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :commits, :forward_merge_queue, type: :uuid, index: {algorithm: :concurrently}
  end
end
