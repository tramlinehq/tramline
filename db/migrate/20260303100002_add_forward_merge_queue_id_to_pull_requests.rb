class AddForwardMergeIdToPullRequests < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :pull_requests, :forward_merge, type: :uuid, index: {algorithm: :concurrently}
  end
end
