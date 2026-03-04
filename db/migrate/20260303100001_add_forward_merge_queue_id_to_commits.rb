class AddForwardMergeIdToCommits < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :commits, :forward_merge, type: :uuid, index: {algorithm: :concurrently}
  end
end
